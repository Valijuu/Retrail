import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';
import '../../data/repositories/data_providers.dart';
import '../../domain/activity_type.dart';
import '../../domain/formatters.dart';
import '../../domain/ride_title.dart';
import '../../l10n/app_localizations.dart';
import '../../map/preview_projection.dart';
import '../../map/route_preview.dart';
import '../active_ride/active_ride_providers.dart';
import '../home/navigation_launcher.dart';
import '../onboarding/activity_type_ui.dart';
import 'history_items.dart';

/// One ride row: cached-PNG thumbnail (no per-scroll tiles), navigate-to-start,
/// favorite toggle (with pulse), title/distance/meta, chips and a 3-dot
/// edit/delete menu. Ports `RideHistoryListItem`.
class HistoryRideCard extends ConsumerStatefulWidget {
  const HistoryRideCard({
    super.key,
    required this.entry,
    required this.selectionMode,
    required this.selected,
    required this.highlighted,
    required this.onTap,
    required this.onOpenMap,
    required this.onLongPress,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFavorite,
  });

  final RideEntryItem entry;
  final bool selectionMode;
  final bool selected;
  final bool highlighted;
  /// Card tap — only acts in selection mode (toggles the selection).
  final VoidCallback onTap;

  /// Map-thumbnail tap outside selection mode — opens the ride detail. Only
  /// the map opens it, not the whole card.
  final VoidCallback onOpenMap;
  final VoidCallback onLongPress;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;

  @override
  ConsumerState<HistoryRideCard> createState() => _HistoryRideCardState();
}

class _HistoryRideCardState extends ConsumerState<HistoryRideCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 130),
    lowerBound: 1.0,
    upperBound: 1.3,
  );

  @override
  void didUpdateWidget(HistoryRideCard old) {
    super.didUpdateWidget(old);
    final was = old.entry.ride.isFavorite;
    final now = widget.entry.ride.isFavorite;
    if (now && !was) {
      _pulse.forward(from: 1.0).then((_) => _pulse.reverse());
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).textTheme;
    final ride = widget.entry.ride;
    final stats = widget.entry.stats;
    final hasRoute = ride.hasRoute;
    final km = stats.distanceMetres / 1000;
    final distanceStr = km < 10 ? km.toStringAsFixed(1) : km.toStringAsFixed(0);
    final locale = Localizations.localeOf(context).toString();
    final title = rideDisplayTitle(ride, locale: locale);
    final meta = '${formatRideTime(ride.date, locale: locale)} · '
        '${formatDuration(stats.durationMs)} · '
        'Ø ${stats.avgSpeedKmh.round()} km/h';
    final activity = ActivityType.fromId(ride.typ);

    return InkWell(
      onTap: widget.selectionMode ? widget.onTap : null,
      onLongPress: widget.onLongPress,
      borderRadius: AppShapes.heroCard,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: AppShapes.heroCard,
          border: (widget.selected || widget.highlighted)
              ? Border.all(color: colors.primary, width: 2)
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Thumbnail(
              rideId: ride.rideId,
              hasRoute: hasRoute,
              title: title,
              selectionMode: widget.selectionMode,
              selected: widget.selected,
              onTap: widget.selectionMode ? widget.onTap : widget.onOpenMap,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyMedium
                                ?.copyWith(color: colors.onSurface)),
                      ),
                      const SizedBox(width: 8),
                      ScaleTransition(
                        scale: _pulse,
                        child: InkResponse(
                          onTap: widget.onToggleFavorite,
                          radius: 20,
                          child: Icon(
                            ride.isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 22,
                            color: ride.isFavorite
                                ? colors.primary
                                : colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('$distanceStr km',
                          style: text.bodyMedium?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w500)),
                      if (!widget.selectionMode) ...[
                        const SizedBox(width: 4),
                        _OverflowMenu(
                          onEdit: widget.onEdit,
                          onDelete: widget.onDelete,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelSmall
                          ?.copyWith(color: colors.onSurfaceVariant)),
                  if (activity != null || stats.avgSpeedKmh > 10 || !hasRoute) ...[
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        if (activity != null)
                          _Chip(
                            label: activity.label(l10n),
                            leading: activity.glyph(
                                size: 13, color: colors.chipSecondaryText),
                            bg: colors.chipSecondary,
                            fg: colors.chipSecondaryText,
                          ),
                        if (stats.avgSpeedKmh > 10)
                          _Chip(
                            label: l10n.chipGreatPace,
                            bg: colors.primaryContainer,
                            fg: colors.onPrimaryContainer,
                          ),
                        if (!hasRoute)
                          _Chip(
                            label: l10n.chipNoRoute,
                            bg: colors.surfaceContainer,
                            fg: colors.onSurfaceVariant,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends ConsumerWidget {
  const _Thumbnail({
    required this.rideId,
    required this.hasRoute,
    required this.title,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
  });

  final int rideId;
  final bool hasRoute;
  final String title;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;

  /// This ride's trackpoints, fetched only when actually needed (a
  /// not-yet-cached preview render, or a navigate-to-start tap) — the list
  /// itself no longer joins them (issue #21).
  Future<List<RoutePoint>> _loadPoints(WidgetRef ref) async {
    final tps =
        await ref.read(trackpointRepositoryProvider).getForRide(rideId).first;
    return [for (final tp in tps) (lat: tp.latitude, lng: tp.longitude)];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).textTheme;
    return ClipRRect(
      // Independently round the thumbnail's top corners (as the original did),
      // so the full-bleed preview image can't bleed past the card's rounded
      // corners — which is what made the highlight border look broken at the
      // top-left/top-right corners.
      borderRadius: BorderRadius.only(
        topLeft: AppShapes.heroCard.topLeft,
        topRight: AppShapes.heroCard.topRight,
      ),
      child: AspectRatio(
      // Pin the slot to the render aspect so BoxFit.cover shows the whole route
      // (render aspect == display aspect → no crop). Single source of truth.
      aspectRatio: previewAspectRatio,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              key: ValueKey('ride_map_$rideId'),
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: ColoredBox(
                color: hasRoute ? colors.mapTerrain : colors.mapTerrainGrid,
                child: hasRoute
                    ? RoutePreview(
                        rideId: rideId,
                        hasRoute: true,
                        pointsLoader: () => _loadPoints(ref),
                        cache: ref.watch(routePreviewCacheProvider),
                        cacheWidth: previewImageCacheWidth,
                      )
                    : Center(
                        child: Text(l10n.chipNoRoute,
                            style: text.bodyMedium
                                ?.copyWith(color: colors.onSurfaceVariant)),
                      ),
              ),
            ),
          ),
          if (selectionMode)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? colors.primary
                      : colors.surface.withValues(alpha: 0.85),
                  border: selected
                      ? null
                      : Border.all(color: colors.onSurfaceVariant, width: 1.5),
                ),
                child: selected
                    ? Icon(Icons.check, size: 16, color: colors.onPrimary)
                    : null,
              ),
            ),
          if (hasRoute && !selectionMode)
            Positioned(
              bottom: 8,
              right: 8,
              child: Material(
                color: colors.surface.withValues(alpha: 0.92),
                shape: const CircleBorder(),
                child: IconButton(
                  iconSize: 20,
                  onPressed: () async {
                    final points = await _loadPoints(ref);
                    if (points.isEmpty) return;
                    ref.read(navigationLauncherProvider).launchTo(
                        points.first.lat, points.first.lng, title);
                  },
                  icon: Icon(Icons.directions, color: colors.primary),
                  tooltip: l10n.a11yNavigateToStartPoint,
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }
}

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({required this.onEdit, required this.onDelete});
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).extension<AppColors>()!;
    return PopupMenuButton<int>(
      tooltip: l10n.a11yMoreOptions,
      icon: Icon(Icons.more_vert, size: 20, color: colors.onSurfaceVariant),
      onSelected: (v) => v == 0 ? onEdit() : onDelete(),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 0,
          child: Row(
            children: [
              Icon(Icons.edit, color: colors.onSurface, size: 20),
              const SizedBox(width: 12),
              Text(l10n.actionEdit),
            ],
          ),
        ),
        PopupMenuItem(
          value: 1,
          child: Row(
            children: [
              Icon(Icons.delete, color: colors.deleteActionText, size: 20),
              const SizedBox(width: 12),
              Text(l10n.actionDelete,
                  style: TextStyle(color: colors.deleteActionText)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label, required this.bg, required this.fg, this.leading});
  final String label;
  final Color bg;
  final Color fg;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: bg, borderRadius: const BorderRadius.all(Radius.circular(20))),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 4),
          ],
          Text(label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: fg)),
        ],
      ),
    );
  }
}
