import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';
import '../../domain/formatters.dart';
import '../../domain/stats_aggregation.dart';
import '../../l10n/app_localizations.dart';

/// "This week" hero card: week/day/year distances + week stats
/// (Ø speed, ride count, duration). Mirrors the original `WeeklyHeroCard`.
class WeeklyHeroCard extends StatelessWidget {
  const WeeklyHeroCard({
    super.key,
    required this.daily,
    required this.weekly,
    required this.yearly,
  });

  final WeeklyStats daily;
  final WeeklyStats weekly;
  final WeeklyStats yearly;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = AppLocalizations.of(context);
    final nf = NumberFormat('0.0');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: AppShapes.heroCard,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _DistanceColumn(label: l10n.homeWeekSection, km: weekly.totalKm, nf: nf),
              _DistanceColumn(label: l10n.homeDaySection, km: daily.totalKm, nf: nf),
              _DistanceColumn(label: l10n.homeYearSection, km: yearly.totalKm, nf: nf),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatCell(
                  label: l10n.statTempoKmh,
                  value: 'Ø ${nf.format(weekly.avgSpeedKmh)}'),
              const SizedBox(width: 8),
              _StatCell(label: l10n.statRides, value: '${weekly.rideCount}'),
              const SizedBox(width: 8),
              _StatCell(
                  label: l10n.statDurationLabel,
                  value: formatDuration(weekly.totalDurationSeconds * 1000)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DistanceColumn extends StatelessWidget {
  const _DistanceColumn({required this.label, required this.km, required this.nf});
  final String label;
  final double km;
  final NumberFormat nf;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall
                  ?.copyWith(color: colors.onPrimaryContainer.withValues(alpha: 0.6))),
          const SizedBox(height: 4),
          Text('${nf.format(km)} km',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleMedium?.copyWith(
                  color: colors.onPrimaryContainer, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(color: colors.surface, borderRadius: AppShapes.card),
        child: Column(
          children: [
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelSmall?.copyWith(
                    color: colors.onPrimaryContainer.withValues(alpha: 0.6))),
            const SizedBox(height: 4),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium?.copyWith(
                    color: colors.onPrimaryContainer, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
