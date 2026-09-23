import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/activity_type.dart';
import '../../l10n/app_localizations.dart';
import '../onboarding/activity_type_ui.dart';
import '../settings/settings_providers.dart';
import 'history_filter.dart';
import 'history_providers.dart';
import 'widgets/pill_dropdown.dart';

/// Year / period / sort / activity / favorites filter sheet. Filters apply
/// live via [historyFilterProvider] as soon as a chip/dropdown is touched —
/// there is no separate "Apply" step; the sheet is dismissed by dragging
/// down or tapping outside it. Ports `FilterBottomSheet`.
class HistoryFilterSheet extends ConsumerWidget {
  const HistoryFilterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).textTheme;
    final filter = ref.watch(historyFilterProvider);
    final notifier = ref.read(historyFilterProvider.notifier);
    final availableYears = ref.watch(yearPickerItemsProvider);
    final locale = ref.watch(dateFormatLocaleProvider);

    // A past/future year already fixes the window to that whole calendar
    // year (see `effectiveRange`) — the week/month chips are relative to
    // "now" and would be misleading, so hide them. ("This year" as its own
    // chip is gone — selecting the current year in the dropdown above does
    // the same job.)
    final showPeriodChips =
        filter.year == null || filter.year == DateTime.now().year;
    // The Von/Bis month range only means anything within one selected year
    // (see `HistoryFilter.monthFrom`) — unlike the period chips above, it
    // stays available for a past/future year too, not just the current one.
    final showMonthRange = filter.year != null;
    final periods = showPeriodChips
        ? <(String, TimePeriod)>[
            (l10n.periodThisWeek, TimePeriod.thisWeek),
            (l10n.periodThisMonth, TimePeriod.thisMonth),
          ]
        : const <(String, TimePeriod)>[];
    final sorts = <(String, SortOrder)>[
      (l10n.sortNewest, SortOrder.date),
      (l10n.sortDistance, SortOrder.distance),
      (l10n.sortSpeed, SortOrder.speed),
      (l10n.sortDuration, SortOrder.duration),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(l10n.historyFilterTitle,
                      style:
                          text.titleLarge?.copyWith(color: colors.onSurface)),
                ),
                TextButton(
                  onPressed: notifier.reset,
                  child: Text(l10n.actionReset,
                      style: TextStyle(color: colors.primary)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionLabel(l10n.historySectionYear),
            const SizedBox(height: 8),
            PillDropdown<int?>(
              value: filter.year,
              items: [null, ...availableYears],
              itemLabel: (year) => year == null ? l10n.historyYearAll : '$year',
              onChanged: notifier.setYear,
            ),
            if (showMonthRange) ...[
              const SizedBox(height: 20),
              _SectionLabel(l10n.historySectionMonthRange),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _MonthRangeDropdown(
                      label: l10n.historyMonthFromLabel,
                      value: filter.monthFrom ?? 1,
                      locale: locale,
                      onChanged: notifier.setMonthFrom,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MonthRangeDropdown(
                      label: l10n.historyMonthToLabel,
                      value: filter.monthTo ?? 12,
                      locale: locale,
                      onChanged: notifier.setMonthTo,
                    ),
                  ),
                ],
              ),
            ],
            if (showPeriodChips) ...[
              const SizedBox(height: 20),
              _SectionLabel(l10n.historySectionPeriod),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Multi-select: chips toggle and combine (union); "All" clears.
                  FilterChip(
                    selected: filter.periods.isEmpty,
                    onSelected: (_) => notifier.clearPeriods(),
                    label: Text(l10n.periodAll),
                  ),
                  for (final (label, value) in periods)
                    FilterChip(
                      selected: filter.periods.contains(value),
                      onSelected: (_) => notifier.togglePeriod(value),
                      label: Text(label),
                    ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            _SectionLabel(l10n.historySectionSort),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, value) in sorts)
                  FilterChip(
                    selected: filter.sort == value,
                    onSelected: (_) => notifier.setSort(value),
                    label: Text(label),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionLabel(l10n.historySectionActivity),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Multi-select: pick any combination of activities; "All" clears.
                FilterChip(
                  selected: filter.activities.isEmpty,
                  onSelected: (_) => notifier.clearActivities(),
                  label: Text(l10n.activityAll),
                ),
                for (final type in ActivityType.values)
                  FilterChip(
                    selected: filter.activities.contains(type),
                    onSelected: (_) => notifier.toggleActivity(type),
                    avatar: type.glyph(size: 18),
                    label: Text(type.label(l10n)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.favorite, size: 20, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(l10n.historyFilterFavoritesOnly,
                      style:
                          text.bodyLarge?.copyWith(color: colors.onSurface)),
                ),
                Switch(
                  value: filter.favoritesOnly,
                  onChanged: notifier.setFavoritesOnly,
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Text(text.toUpperCase(),
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: colors.onSurfaceVariant));
  }
}

/// One half (Von or Bis) of the month-range picker: a small dimmed label
/// above a [PillDropdown] of the 12 localized month names.
class _MonthRangeDropdown extends StatelessWidget {
  const _MonthRangeDropdown({
    required this.label,
    required this.value,
    required this.locale,
    required this.onChanged,
  });

  final String label;
  final int value;
  final String locale;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final monthFormat = DateFormat.MMMM(locale);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: colors.onSurfaceVariant)),
        const SizedBox(height: 4),
        PillDropdown<int>(
          value: value,
          items: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
          itemLabel: (month) => monthFormat.format(DateTime(2000, month)),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
