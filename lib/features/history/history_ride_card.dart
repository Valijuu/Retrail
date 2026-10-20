import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_shapes.dart';
import '../../domain/activity_type.dart';
import '../../domain/formatters.dart';
import '../../domain/ride_title.dart';
import '../../l10n/app_localizations.dart';
import '../../map/map_attribution.dart';
import '../../map/preview_projection.dart';
import '../home/navigation_chooser.dart';
import '../home/navigation_launcher.dart';
import '../onboarding/activity_type_ui.dart';
import 'history_items.dart';
import 'widgets/ride_preview_thumbnail.dart';
import '../../core/theme/theme_context.dart';

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
    this.onFollowRoute,
    this.onOpenRouteGroup,
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

  /// Starts "Follow route"; null hides the menu entry.
  final VoidCallback? onFollowRoute;

  /// Opens the comparison of this ride's route group from its Followed /
  /// "n× followed" chip (Spec 20).
  final VoidCallback? onOpenRouteGroup;

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
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final ride = widget.entry.ride;
    final stats = widget.entry.stats;
    final hasRoute = ride.hasRoute;
    // Any route is offered; the launcher explains one that can't be followed.
    final canFollow = hasRoute;
    final locale = Localizations.localeOf(context).toString();
    final distance = formatShortDistanceKm(
      stats.distanceMetres,
      locale: locale,
    );
    final title = rideDisplayTitle(ride, locale: locale);
    final meta =
        '${formatRideTime(ride.date, locale: locale)} · '
        '${formatDuration(stats.durationMs)} · '
        'Ø ${stats.avgSpeedKmh.round()} km/h';
    final activity = ActivityType.fromId(ride.typ);
    final isFollow = ride.followedRideId != null;
    final followCount = widget.entry.followCount;
    final openGroup = widget.selectionMode ? null : widget.onOpenRouteGroup;

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
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium?.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
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
                      Text(
                        distance,
                        style: text.bodyMedium?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (!widget.selectionMode) ...[
                        const SizedBox(width: 4),
                        _OverflowMenu(
                          onEdit: widget.onEdit,
                          onDelete: widget.onDelete,
                          onFollowRoute: canFollow
                              ? widget.onFollowRoute
                              : null,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (activity != null ||
                      stats.avgSpeedKmh > 10 ||
                      !hasRoute ||
                      isFollow ||
                      followCount > 0) ...[
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        if (activity != null)
                          _Chip(
                            label: activity.label(l10n),
                            leading: activity.glyph(
                              size: 13,
                              color: colors.chipSecondaryText,
                            ),
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
                        if (isFollow)
                          _Chip(
                            label: l10n.chipFollowed,
                            leading: Icon(
                              Icons.alt_route,
                              size: 13,
                              color: colors.onPrimaryContainer,
                            ),
                            bg: colors.primaryContainer,
                            fg: colors.onPrimaryContainer,
                            onTap: openGroup,
                          ),
                        if (followCount > 0)
                          _Chip(
                            label: l10n.chipFollowCount(followCount),
                            leading: Icon(
                              Icons.alt_route,
                              size: 13,
                              color: colors.onPrimaryContainer,
                            ),
                            bg: colors.primaryContainer,
                            fg: colors.onPrimaryContainer,
                            onTap: openGroup,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
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
                child: RidePreviewThumbnail(rideId: rideId, hasRoute: hasRoute),
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
                        : Border.all(
                            color: colors.onSurfaceVariant,
                            width: 1.5,
                          ),
                  ),
                  child: selected
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: colors.onPrimary,
                          semanticLabel: l10n.a11ySelected,
                        )
                      : null,
                ),
              ),
            // Plain text: the whole thumbnail is the card's tap target. Bottom
            // left, clear of the navigate button.
            if (hasRoute)
              const Positioned(
                left: kMapAttributionInset,
                bottom: kMapAttributionInset,
                child: IgnorePointer(child: MapAttribution()),
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
                      final points = await loadRidePoints(ref, rideId);
                      if (points.isEmpty || !context.mounted) return;
                      await navigateTo(
                        context,
                        ref.read(navigationLauncherProvider),
                        points.first.lat,
                        points.first.lng,
                        title,
                      );
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

enum _MenuAction { follow, edit, delete }

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({
    required this.onEdit,
    required this.onDelete,
    this.onFollowRoute,
  });
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onFollowRoute;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    return PopupMenuButton<_MenuAction>(
      tooltip: l10n.a11yMoreOptions,
      // The M3 default is the seed-generated surfaceContainer, a pink that
      // clashes with the beige card and the grey map; Surface + no tint
      // matches the floating map buttons instead.
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: AppShapes.card),
      icon: Icon(Icons.more_vert, size: 20, color: colors.onSurfaceVariant),
      onSelected: (v) => switch (v) {
        _MenuAction.follow => onFollowRoute?.call(),
        _MenuAction.edit => onEdit(),
        _MenuAction.delete => onDelete(),
      },
      itemBuilder: (context) => [
        if (onFollowRoute != null)
          PopupMenuItem(
            value: _MenuAction.follow,
            child: Row(
              children: [
                Icon(Icons.route, color: colors.onSurface, size: 20),
                const SizedBox(width: 12),
                Text(l10n.followRouteAction),
              ],
            ),
          ),
        PopupMenuItem(
          value: _MenuAction.edit,
          child: Row(
            children: [
              Icon(Icons.edit, color: colors.onSurface, size: 20),
              const SizedBox(width: 12),
              Text(l10n.actionEdit),
            ],
          ),
        ),
        PopupMenuItem(
          value: _MenuAction.delete,
          child: Row(
            children: [
              Icon(Icons.delete, color: colors.deleteActionText, size: 20),
              const SizedBox(width: 12),
              Text(
                l10n.actionDelete,
                style: TextStyle(color: colors.deleteActionText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.bg,
    required this.fg,
    this.leading,
    this.onTap,
  });
  final String label;
  final Color bg;
  final Color fg;
  final Widget? leading;

  /// Makes the chip a button of its own, so a tap doesn't reach the card.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      decoration: BoxDecoration(color: bg, borderRadius: AppShapes.pill),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 4)],
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
          ),
        ],
      ),
    );
    final tap = onTap;
    if (tap == null) return chip;
    return Semantics(
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: tap, borderRadius: AppShapes.pill, child: chip),
      ),
    );
  }
}
