import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shapes.dart';
import '../../../domain/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../../tracking/ride_tracking_state.dart';

/// The bottom sheet of live stats (speed, distance, duration, top speed) with
/// the pause/resume + stop actions.
class RideStatsPanel extends StatelessWidget {
  const RideStatsPanel({
    super.key,
    required this.state,
    required this.onPauseResume,
    required this.onStop,
  });

  final RideTrackingState state;
  final VoidCallback onPauseResume;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).extension<AppColors>()!;
    final speed = state.speedKmh;
    return Container(
      width: double.infinity,
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6, bottom: 8),
            width: 24,
            height: 3,
            decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _StatCell(
                    label: l10n.mapStatSpeed,
                    value: formatSpeedKmh(speed),
                    valueColor:
                        (speed ?? 0) > 0 ? colors.primary : colors.onSurface,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: _StatCell(
                    label: l10n.mapStatDistance,
                    value: formatDistanceKm(state.distanceMetres),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _StatCell(
                    label: l10n.mapStatDuration,
                    value: formatElapsed(state.elapsedSeconds),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: _StatCell(
                    label: l10n.mapStatMaxSpeed,
                    value: formatSpeedKmh(state.maxSpeedKmh),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: state.isPaused ? l10n.mapResumeRide : l10n.mapPauseRide,
                  filled: state.isPaused,
                  onTap: onPauseResume,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: l10n.mapStopRide,
                  filled: false,
                  onTap: onStop,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
          color: colors.surfaceContainer, borderRadius: AppShapes.input),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant)),
          Text(value,
              style: text.titleMedium
                  ?.copyWith(color: valueColor ?? colors.onSurface)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final style = ButtonStyle(
      shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AppShapes.pill)),
      backgroundColor:
          WidgetStatePropertyAll(filled ? colors.primary : colors.surface),
      foregroundColor:
          WidgetStatePropertyAll(filled ? colors.onPrimary : colors.primary),
      side: filled
          ? null
          : WidgetStatePropertyAll(
              BorderSide(color: colors.surfaceContainer, width: 1.5)),
    );
    return TextButton(
      onPressed: onTap,
      style: style,
      child: Text(label, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}
