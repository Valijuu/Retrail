import 'package:flutter/material.dart';

import '../../core/theme/app_shapes.dart';
import '../../domain/formatters.dart';
import '../../domain/stats_aggregation.dart';
import '../../l10n/app_localizations.dart';
import 'home_providers.dart';
import '../../core/theme/theme_context.dart';

/// Hero card: week/day/year distances on top — each a tappable period, the
/// [selected] one highlighted — and the selected period's stats below
/// (Ø speed, ride count, duration). Based on the original `WeeklyHeroCard`,
/// whose stat row was always the week without saying so.
class WeeklyHeroCard extends StatelessWidget {
  const WeeklyHeroCard({
    super.key,
    required this.daily,
    required this.weekly,
    required this.yearly,
    this.selected = StatsPeriod.week,
    this.onSelect,
  });

  final WeeklyStats daily;
  final WeeklyStats weekly;
  final WeeklyStats yearly;
  final StatsPeriod selected;
  final ValueChanged<StatsPeriod>? onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final stats = switch (selected) {
      StatsPeriod.week => weekly,
      StatsPeriod.day => daily,
      StatsPeriod.year => yearly,
    };
    Widget column(StatsPeriod period, String label, WeeklyStats s) =>
        _DistanceColumn(
          label: label,
          km: s.totalKm,
          locale: locale,
          selected: period == selected,
          onTap: onSelect == null ? null : () => onSelect!(period),
        );

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
              column(StatsPeriod.week, l10n.homeWeekSection, weekly),
              column(StatsPeriod.day, l10n.homeDaySection, daily),
              column(StatsPeriod.year, l10n.homeYearSection, yearly),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatCell(
                  label: l10n.statTempoKmh,
                  value: 'Ø ${formatDecimal(stats.avgSpeedKmh, 1, locale: locale)}'),
              const SizedBox(width: 8),
              _StatCell(label: l10n.statRides, value: '${stats.rideCount}'),
              const SizedBox(width: 8),
              _StatCell(
                  label: l10n.statDurationLabel,
                  value: formatDuration(stats.totalDurationSeconds * 1000)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DistanceColumn extends StatelessWidget {
  const _DistanceColumn({
    required this.label,
    required this.km,
    required this.locale,
    required this.selected,
    this.onTap,
  });
  final String label;
  final double km;
  final String locale;
  final bool selected;
  final VoidCallback? onTap;

  /// Unselected periods recede so the highlighted one reads as "these stats".
  static const double _dimmedAlpha = 0.6;
  static const double _highlightAlpha = 0.12;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final ink = colors.onPrimaryContainer;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppShapes.card,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? ink.withValues(alpha: _highlightAlpha)
                  : Colors.transparent,
              borderRadius: AppShapes.card,
            ),
            child: Column(
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(
                        color: ink.withValues(
                            alpha: selected ? 0.85 : _dimmedAlpha))),
                const SizedBox(height: 4),
                Text('${formatDecimal(km, 1, locale: locale)} km',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium?.copyWith(
                        color: selected
                            ? ink
                            : ink.withValues(alpha: _dimmedAlpha),
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
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
    final colors = context.colors;
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
            // Cross-fade when the period changes, so the switch is visible.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Text(value,
                  key: ValueKey(value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }
}
