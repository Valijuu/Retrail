import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';
import '../../data/db/ride_with_trackpoints.dart';
import '../../domain/activity_type.dart';
import '../../domain/formatters.dart';
import '../../domain/ride_stats.dart';
import '../../l10n/app_localizations.dart';
import '../../map/live_map.dart';
import '../../map/preview_projection.dart';
import '../onboarding/activity_type_ui.dart';

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).textTheme;
    final ride = widget.rwt.ride;
    final points = <RoutePoint>[
      for (final tp in widget.rwt.trackpoints) (lat: tp.latitude, lng: tp.longitude),
    ];
    final activity = ActivityType.fromId(ride.typ);
    final title = (ride.description?.trim().isNotEmpty ?? false) ? ride.description! : null;
    final comment = (ride.comment?.trim().isNotEmpty ?? false) ? ride.comment! : null;

    if (_fullscreen && points.isNotEmpty) {
      return Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
                child: LiveMap(
                    points: points, fitBounds: true, activityType: activity)),
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
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration:
            BoxDecoration(color: colors.surface, borderRadius: AppShapes.dialog),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 330,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: colors.mapTerrain,
                      child: points.isEmpty
                          ? Center(
                              child: Text(l10n.chipNoRoute,
                                  style: text.bodyMedium
                                      ?.copyWith(color: colors.onSurfaceVariant)))
                          : LiveMap(
                              points: points,
                              fitBounds: true,
                              activityType: activity),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(formatRideDate(ride.date),
                      style: text.titleMedium?.copyWith(color: colors.onSurface)),
                  if (activity != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        activity.glyph(size: 18, color: colors.primary),
                        const SizedBox(width: 6),
                        Text(activity.label(l10n),
                            style: text.bodyMedium?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  if (title != null)
                    Text(title,
                        style: text.bodyLarge?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w500)),
                  if (comment != null)
                    Text(comment,
                        style: text.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontStyle: FontStyle.italic)),
                  const SizedBox(height: 16),
                  Divider(
                      height: 1,
                      color: colors.onSurfaceVariant.withValues(alpha: 0.2)),
                  const SizedBox(height: 16),
                  _DetailRow(
                      label: l10n.detailDistanceLabel,
                      value:
                          '${(widget.stats.distanceMetres / 1000).toStringAsFixed(2)} km'),
                  const SizedBox(height: 10),
                  _DetailRow(
                      label: l10n.detailDurationLabel,
                      value: formatDuration(widget.stats.durationMs)),
                  const SizedBox(height: 10),
                  _DetailRow(
                      label: l10n.detailMaxSpeedLabel,
                      value:
                          '${widget.stats.maxSpeedKmh.toStringAsFixed(1)} km/h'),
                  const SizedBox(height: 10),
                  _DetailRow(
                      label: l10n.detailAvgSpeedLabel,
                      value:
                          '${widget.stats.avgSpeedKmh.toStringAsFixed(1)} km/h'),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: widget.onDismiss,
                      child: Text(l10n.actionClose,
                          style: text.labelLarge?.copyWith(color: colors.primary)),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant)),
        Text(value,
            style: text.bodyMedium
                ?.copyWith(color: colors.onSurface, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon(
      {required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.6),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: AppColors.dark.surface),
        tooltip: tooltip,
      ),
    );
  }
}
