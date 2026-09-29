import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_shapes.dart';
import '../../data/db/ride_with_trackpoints.dart';
import '../../domain/activity_type.dart';
import '../../domain/formatters.dart';
import '../../domain/ride_stats.dart';
import '../../l10n/app_localizations.dart';
import '../../map/live_map.dart';
import '../../map/preview_projection.dart';
import '../onboarding/activity_type_ui.dart';
import '../../core/theme/theme_context.dart';

/// Read-only ride detail: interactive map (with fullscreen), date, activity,
/// title, comment and the four stats. Ports `RideDetailDialog`.
class RideDetailDialog extends StatefulWidget {
  const RideDetailDialog({
    super.key,
    required this.rwt,
    required this.stats,
    required this.onDismiss,
  });

  final RideWithTrackpoints rwt;
  final RideStats stats;
  final VoidCallback onDismiss;

  @override
  State<RideDetailDialog> createState() => _RideDetailDialogState();
}

class _RideDetailDialogState extends State<RideDetailDialog> {
  bool _fullscreen = false;

  /// The map's height on roomy screens (the original's fixed size).
  static const double _mapMaxHeight = 330;

  /// On short screens the map takes at most this share of the dialog height,
  /// leaving room for the details and the Close button.
  static const double _mapMaxHeightShare = 0.4;

  /// The route, built once per ride: a fresh list on every build made the map
  /// re-push its route source on each dialog rebuild (issue #42).
  late List<RoutePoint> _points = _routeOf(widget.rwt);

  static List<RoutePoint> _routeOf(RideWithTrackpoints rwt) => [
        for (final tp in rwt.trackpoints) (lat: tp.latitude, lng: tp.longitude),
      ];

  @override
  void didUpdateWidget(RideDetailDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rwt != oldWidget.rwt) _points = _routeOf(widget.rwt);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final ride = widget.rwt.ride;
    final points = _points;
    final activity = ActivityType.fromId(ride.typ);
    final title = (ride.description?.trim().isNotEmpty ?? false)
        ? ride.description!
        : null;
    final comment = (ride.comment?.trim().isNotEmpty ?? false)
        ? ride.comment!
        : null;

    if (_fullscreen && points.isNotEmpty) {
      return Dialog.fullscreen(
        backgroundColor: context.colors.scrim,
        child: Stack(
          children: [
            Positioned.fill(
              child: LiveMap(
                points: points,
                fitBounds: true,
                activityType: activity,
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: _CircleIcon(
                icon: Icons.close,
                tooltip: l10n.actionClose,
                onTap: () => setState(() => _fullscreen = false),
              ),
            ),
          ],
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      // Wider than the M3 default (40dp side margins): the map + stats deserve
      // most of the screen width.
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppShapes.dialog,
        ),
        // On short screens (iPhone 8) a fixed 330dp map pushed Close below the
        // screen: the map now shrinks to a share of the height, the details
        // scroll, and Close stays pinned at the bottom.
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: math.min(
                  _mapMaxHeight,
                  constraints.maxHeight * _mapMaxHeightShare,
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(
                        color: colors.mapTerrain,
                        child: points.isEmpty
                            ? Center(
                                child: Text(
                                  l10n.chipNoRoute,
                                  style: text.bodyMedium?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : LiveMap(
                                points: points,
                                fitBounds: true,
                                activityType: activity,
                              ),
                      ),
                    ),
                    if (points.isNotEmpty)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _CircleIcon(
                          icon: Icons.fullscreen,
                          tooltip: l10n.a11yFullscreen,
                          onTap: () => setState(() => _fullscreen = true),
                        ),
                      ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatRideDate(ride.date, locale: locale),
                        style: text.titleMedium?.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                      if (activity != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            activity.glyph(size: 18, color: colors.primary),
                            const SizedBox(width: 6),
                            Text(
                              activity.label(l10n),
                              style: text.bodyMedium?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      if (title != null)
                        Text(
                          title,
                          style: text.bodyLarge?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (comment != null)
                        Text(
                          comment,
                          style: text.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      const SizedBox(height: 16),
                      Divider(
                        height: 1,
                        color: colors.onSurfaceVariant.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 16),
                      _DetailRow(
                        label: l10n.detailDistanceLabel,
                        value: formatDistanceKm(
                          widget.stats.distanceMetres,
                          locale: locale,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _DetailRow(
                        label: l10n.detailDurationLabel,
                        value: formatDuration(widget.stats.durationMs),
                      ),
                      const SizedBox(height: 10),
                      _DetailRow(
                        label: l10n.detailMaxSpeedLabel,
                        value: formatSpeedKmh(
                          widget.stats.maxSpeedKmh,
                          locale: locale,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _DetailRow(
                        label: l10n.detailAvgSpeedLabel,
                        value: formatSpeedKmh(
                          widget.stats.avgSpeedKmh,
                          locale: locale,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: widget.onDismiss,
                    child: Text(
                      l10n.actionClose,
                      style: text.labelLarge?.copyWith(color: colors.primary),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Flexible: long labels (German "Höchstgeschwindigkeit") wrap instead
        // of pushing the value off the dialog's edge.
        Flexible(
          child: Text(
            label,
            style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: text.bodyMedium?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Themed like the live map's recenter button and compass (app surface,
    // primary icon) — but translucent, so it doesn't hide the map corner.
    return Material(
      color: colors.surface.withValues(alpha: 0.6),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: colors.primary),
        tooltip: tooltip,
      ),
    );
  }
}
