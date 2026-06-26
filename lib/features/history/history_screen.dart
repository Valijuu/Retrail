import 'dart:async';

import 'package:flutter/material.dart';
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
import '../../data/db/ride_with_trackpoints.dart';
import '../../domain/activity_type.dart';

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
  int? _highlightRideId;
  Timer? _highlightTimer;

  bool get _selectionMode => _selectedIds.isNotEmpty;

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _exitSelection() => setState(() => _selectedIds = {});

  void _toggleSelected(int rideId) => setState(() {
        _selectedIds = {..._selectedIds};
        if (!_selectedIds.remove(rideId)) _selectedIds.add(rideId);
      });

  /// Jump to the ride requested from Home: reset filters if it's hidden, scroll
  /// to it and highlight it briefly. Mirrors the original `LaunchedEffect`.
  void _maybeJumpToTarget() {
    final target = ref.read(historyTargetRideProvider);
    if (target == null) return;
    final items = ref.read(historyItemsProvider).asData?.value ?? [];
    final found = items.any(
        (i) => i is RideEntryItem && i.rwt.ride.rideId == target);
    if (!found) {
      ref.read(historyFilterProvider.notifier).reset();
      return; // re-runs on the next items emission
    }
    ref.read(historyTargetRideProvider.notifier).state = null;
    _targetKey = GlobalKey();
    setState(() => _highlightRideId = target);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final ctx = _targetKey.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.2);
    });
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _highlightRideId = null);
    });
  }

  Future<void> _openFilters() => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
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

  Future<void> _openEdit(RideWithTrackpoints rwt) => showDialog<void>(
        context: context,
        builder: (_) => EditRideDialog(
          initialDescription: rwt.ride.description,
          initialComment: rwt.ride.comment,
          initialType: ActivityType.fromId(rwt.ride.typ),
          onDismiss: () => Navigator.of(context).pop(),
          onSave: (description, comment, type) {
            Navigator.of(context).pop();
            ref
                .read(historyControllerProvider)
                .updateRideDetails(rwt.ride.rideId, description, comment, type);
          },
        ),
      );

  Future<void> _openDetail(RideEntryItem entry) => showDialog<void>(
        context: context,
        builder: (_) => RideDetailDialog(
          rwt: entry.rwt,
          stats: entry.stats,
          onDismiss: () => Navigator.of(context).pop(),
        ),
      );

  @override
  Widget build(BuildContext context) {
    ref.listen(historyTargetRideProvider, (_, _) => _maybeJumpToTarget());
    ref.listen(historyItemsProvider, (_, _) => _maybeJumpToTarget());

    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).extension<AppColors>()!;
    final items = ref.watch(historyItemsProvider).asData?.value ?? const [];
    final hasRides = items.any((i) => i is RideEntryItem);

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
            todayLabel: l10n.dateToday, yesterdayLabel: l10n.dateYesterday);
        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 5),
          child: Text(label.toUpperCase(),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: colors.onSurfaceVariant)),
        );
      case RideEntryItem():
        final rideId = item.rwt.ride.rideId;
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
          onEdit: () => _openEdit(item.rwt),
          onDelete: () => _confirmDelete(single: rideId),
          onToggleFavorite: () =>
              ref.read(historyControllerProvider).toggleFavorite(item.rwt.ride),
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
  const _SelectionBar(
      {required this.count, required this.onClose, required this.onDelete});
  final int count;
  final VoidCallback onClose;
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
            onPressed: onDelete,
            icon: Icon(Icons.delete, color: colors.primary),
            tooltip: l10n.actionDelete,
          ),
        ],
      ),
    );
  }
}
