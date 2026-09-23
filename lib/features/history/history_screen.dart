import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';
import '../../l10n/app_localizations.dart';
import '../shell/main_shell.dart';
import 'confirm_delete_dialog.dart';
import 'edit_ride_dialog.dart';
import 'filter_sheet.dart';
import 'history_items.dart';
import 'history_providers.dart';
import 'history_ride_card.dart';
import 'ride_detail_dialog.dart';
import '../../data/db/app_database.dart' show Ride;
import '../../data/db/ride_with_trackpoints.dart';
import '../../data/repositories/data_providers.dart';
import '../../domain/activity_type.dart';
import '../../map/preview_projection.dart';
import '../active_ride/active_ride_providers.dart';

/// The history tab: filtered/sorted/date-grouped list of ride cards with search,
/// a filter sheet, multi-select + batch delete, per-row edit/delete, a detail
/// dialog, and jump-to-ride from Home. Ports `RideHistoryPage`.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  GlobalKey _targetKey = GlobalKey();
  bool _showSearch = false;
  Set<int> _selectedIds = {};
  bool _selectionModeActive = false;
  int? _highlightRideId;
  Timer? _highlightTimer;
  bool _warmedInitialItems = false;

  /// Selection mode stays active — even with zero rides selected — until the
  /// user explicitly closes it via the X, rather than exiting automatically
  /// when the last selection is deselected.
  bool get _selectionMode => _selectionModeActive;

  @override
  void initState() {
    super.initState();
    // Consume a jump target parked BEFORE this screen mounted. Home sets the
    // target and then switches tabs; the PageView builds this screen fresh on
    // most visits, so the `ref.listen`s in build never see that change — they
    // only fire on LATER emissions (which is why the jump used to work once,
    // then only after something re-emitted the items, e.g. a favorite toggle).
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeJumpToTarget();
    });
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _exitSelection() => setState(() {
        _selectedIds = {};
        _selectionModeActive = false;
      });

  void _toggleSelected(int rideId) => setState(() {
        _selectionModeActive = true;
        _selectedIds = {..._selectedIds};
        if (!_selectedIds.remove(rideId)) _selectedIds.add(rideId);
      });

  /// Selects every currently visible (i.e. already filtered) ride, or — if
  /// all of them are already selected — deselects everything (toggle).
  void _selectAll() {
    final items = ref.read(historyItemsProvider).asData?.value ?? const [];
    final visibleIds = {
      for (final item in items)
        if (item is RideEntryItem) item.ride.rideId,
    };
    setState(() {
      _selectedIds =
          _selectedIds.containsAll(visibleIds) ? {} : visibleIds;
    });
  }

  /// Jump to the ride requested from Home: reset filters if it's hidden, scroll
  /// to it and highlight it briefly. Mirrors the original `LaunchedEffect`.
  void _maybeJumpToTarget() {
    final target = ref.read(historyTargetRideProvider);
    if (target == null) return;
    final items = ref.read(historyItemsProvider).asData?.value ?? [];
    final found =
        items.any((i) => i is RideEntryItem && i.ride.rideId == target);
    if (!found) {
      ref.read(historyFilterProvider.notifier).reset();
      return; // re-runs on the next items emission
    }
    ref.read(historyTargetRideProvider.notifier).state = null;
    _targetKey = GlobalKey();
    setState(() => _highlightRideId = target);
    SchedulerBinding.instance
        .addPostFrameCallback((_) => _revealTarget(items, target));
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _highlightRideId = null);
    });
  }

  /// Scrolls the target card into view. `ensureVisible` only works when the
  /// card is BUILT (viewport + cache extent) — for rides further down the
  /// list its key has no context and the jump used to silently no-op. Jump
  /// near the card's estimated offset first so the lazy list builds it, then
  /// fine-tune; bounded retries cover estimate error.
  void _revealTarget(List<HistoryItem> items, int target, {int attempt = 0}) {
    if (!mounted) return;
    final ctx = _targetKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, alignment: 0.2);
      return;
    }
    if (attempt >= 3 || !_scrollController.hasClients) return;
    final estimate = estimatedOffsetOf(items, target)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.jumpTo(estimate);
    SchedulerBinding.instance.addPostFrameCallback(
        (_) => _revealTarget(items, target, attempt: attempt + 1));
  }

  /// Pre-warms ride previews as soon as the list data arrives, instead of when
  /// each card scrolls into view: ensures the PNG exists on disk + fills the
  /// cache's sync memo (so cards build their image on the first frame), and
  /// pre-decodes the first [_precacheDecodes] into the framework [ImageCache].
  /// Scrolling then never waits on file checks, renders, or decodes.
  /// Re-running on every items emission is cheap — warmed rides hit the memo.
  /// 60 decoded thumbnails ≈ 34 MB — comfortably inside the framework
  /// ImageCache's 100 MB default; beyond that the enlarged cache extent
  /// decode-ahead covers it.
  static const _precacheDecodes = 60;

  void _warmPreviews(List<HistoryItem> items) {
    final cache = ref.read(routePreviewCacheProvider);
    final trackpoints = ref.read(trackpointRepositoryProvider);
    final brightness = Theme.of(context).brightness;
    var decodesLeft = _precacheDecodes;
    for (final item in items) {
      if (item is! RideEntryItem || !item.ride.hasRoute) continue;
      final rideId = item.ride.rideId;
      final precache = decodesLeft-- > 0;
      unawaited(trackpoints.getForRide(rideId).first.then((tps) async {
        if (tps.isEmpty) return;
        final points = <RoutePoint>[
          for (final tp in tps) (lat: tp.latitude, lng: tp.longitude),
        ];
        final file =
            await cache.ensurePreview(rideId, points, brightness: brightness);
        if (!mounted || !precache) return;
        // Same provider shape as the card's Image.file(cacheWidth: ...) so the
        // decoded frame is an exact ImageCache hit when the card builds.
        precacheImage(
            ResizeImage(FileImage(file), width: previewImageCacheWidth),
            context);
      }).catchError((Object _) {}));
    }
  }

  Future<void> _openFilters() => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor:
            Theme.of(context).extension<AppColors>()!.surface,
        builder: (_) => const HistoryFilterSheet(),
      );

  Future<void> _confirmDelete({int? single, bool batch = false}) async {
    final ids = batch ? _selectedIds.toList() : [single!];
    await showDialog<void>(
      context: context,
      builder: (_) => ConfirmDeleteDialog(
        count: ids.length,
        onDismiss: () => Navigator.of(context).pop(),
        onConfirm: () {
          Navigator.of(context).pop();
          final controller = ref.read(historyControllerProvider);
          if (batch) {
            controller.deleteRides(ids);
            _exitSelection();
          } else {
            controller.deleteRide(single!);
          }
        },
      ),
    );
  }

  Future<void> _openEdit(Ride ride) => showDialog<void>(
        context: context,
        builder: (_) => EditRideDialog(
          initialDescription: ride.description,
          initialComment: ride.comment,
          initialType: ActivityType.fromId(ride.typ),
          onDismiss: () => Navigator.of(context).pop(),
          onSave: (description, comment, type) {
            Navigator.of(context).pop();
            ref
                .read(historyControllerProvider)
                .updateRideDetails(ride.rideId, description, comment, type);
          },
        ),
      );

  /// Fetches this ride's trackpoints on demand — the list itself doesn't have
  /// them (issue #21) — then opens the read-only detail dialog.
  Future<void> _openDetail(RideEntryItem entry) async {
    final tps = await ref
        .read(trackpointRepositoryProvider)
        .getForRide(entry.ride.rideId)
        .first;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => RideDetailDialog(
        rwt: RideWithTrackpoints(ride: entry.ride, trackpoints: tps),
        stats: entry.stats,
        onDismiss: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(historyTargetRideProvider, (_, _) => _maybeJumpToTarget());
    ref.listen(historyItemsProvider, (_, next) {
      _maybeJumpToTarget();
      final items = next.asData?.value;
      if (items != null) _warmPreviews(items);
    });

    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).extension<AppColors>()!;
    final items = ref.watch(historyItemsProvider).asData?.value ?? const [];
    final hasRides = items.any((i) => i is RideEntryItem);

    // The listen above only fires on *changes* — when the tab mounts with data
    // already loaded, warm the previews once from here (post-frame, so the
    // first layout isn't delayed).
    if (!_warmedInitialItems && hasRides) {
      _warmedInitialItems = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _warmPreviews(items);
      });
    }

    // Keep the search field in sync with the filter (e.g. Reset clears query).
    final query = ref.watch(historyFilterProvider).query;
    if (_searchController.text != query) {
      _searchController.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }

    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitSelection();
      },
      child: ColoredBox(
        color: colors.surface,
        child: SafeArea(
          child: Column(
            children: [
              if (_selectionMode)
                _SelectionBar(
                  count: _selectedIds.length,
                  onClose: _exitSelection,
                  onSelectAll: _selectAll,
                  onDelete: () => _confirmDelete(batch: true),
                )
              else
                _FilterBar(
                  searchController: _searchController,
                  showSearch: _showSearch,
                  activeFilterCount: ref.watch(activeFilterCountProvider),
                  onToggleSearch: () =>
                      setState(() => _showSearch = !_showSearch),
                  onSearchChange: (q) =>
                      ref.read(historyFilterProvider.notifier).setQuery(q),
                  onOpenFilters: _openFilters,
                ),
              Expanded(
                child: hasRides
                    ? ListView.separated(
                        controller: _scrollController,
                        // Build ~4-5 cards ahead of the viewport so preview
                        // PNGs resolve/decode + upload well before their card
                        // scrolls in — at slow scroll speeds nothing is ever
                        // built at the viewport edge (visible as a hitch).
                        scrollCacheExtent: const ScrollCacheExtent.pixels(1200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, i) => _buildItem(items[i]),
                      )
                    : Center(
                        child: Text(l10n.historyEmpty,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: colors.onSurfaceVariant)),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(HistoryItem item) {
    switch (item) {
      case DateHeaderItem(:final dayKey):
        final l10n = AppLocalizations.of(context);
        final colors = Theme.of(context).extension<AppColors>()!;
        final label = formatDateLabel(dayKey,
            todayLabel: l10n.dateToday,
            yesterdayLabel: l10n.dateYesterday,
            locale: Localizations.localeOf(context).toString());
        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 5),
          child: Text(label.toUpperCase(),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: colors.onSurfaceVariant)),
        );
      case RideEntryItem():
        final rideId = item.ride.rideId;
        return HistoryRideCard(
          key: rideId == _highlightRideId
              ? _targetKey
              : ValueKey('ride_$rideId'),
          entry: item,
          selectionMode: _selectionMode,
          selected: _selectedIds.contains(rideId),
          highlighted: rideId == _highlightRideId,
          onTap: () =>
              _selectionMode ? _toggleSelected(rideId) : _openDetail(item),
          onLongPress: () => _toggleSelected(rideId),
          onEdit: () => _openEdit(item.ride),
          onDelete: () => _confirmDelete(single: rideId),
          onToggleFavorite: () =>
              ref.read(historyControllerProvider).toggleFavorite(item.ride),
        );
    }
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.searchController,
    required this.showSearch,
    required this.activeFilterCount,
    required this.onToggleSearch,
    required this.onSearchChange,
    required this.onOpenFilters,
  });

  final TextEditingController searchController;
  final bool showSearch;
  final int activeFilterCount;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onSearchChange;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(l10n.historyTitle,
                    style: text.titleLarge?.copyWith(color: colors.onSurface)),
              ),
              IconButton(
                onPressed: onToggleSearch,
                icon: Icon(Icons.search, color: colors.primary),
                tooltip: l10n.historySearchCd,
              ),
              Badge.count(
                count: activeFilterCount,
                isLabelVisible: activeFilterCount > 0,
                backgroundColor: colors.primary,
                textColor: colors.onPrimary,
                child: IconButton(
                  onPressed: onOpenFilters,
                  icon: Icon(Icons.filter_list, color: colors.primary),
                  tooltip: l10n.historyFilterCd,
                ),
              ),
            ],
          ),
        ),
        if (showSearch)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: TextField(
              controller: searchController,
              onChanged: onSearchChange,
              decoration: InputDecoration(
                hintText: l10n.historySearchPlaceholder,
                isDense: true,
                border: const OutlineInputBorder(borderRadius: AppShapes.card),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          searchController.clear();
                          onSearchChange('');
                        },
                      ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.onClose,
    required this.onSelectAll,
    required this.onDelete,
  });
  final int count;
  final VoidCallback onClose;
  final VoidCallback onSelectAll;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).extension<AppColors>()!;
    return Container(
      color: colors.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close, color: colors.onSurface),
            tooltip: l10n.a11yExitSelection,
          ),
          Expanded(
            child: Text(l10n.selectionCount(count),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: colors.onSurface)),
          ),
          IconButton(
            onPressed: onSelectAll,
            icon: Icon(Icons.select_all, color: colors.primary),
            tooltip: l10n.selectAll,
          ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.delete, color: colors.primary),
            tooltip: l10n.actionDelete,
          ),
        ],
      ),
    );
  }
}
