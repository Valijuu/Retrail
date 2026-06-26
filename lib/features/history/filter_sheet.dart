import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';
import '../../domain/activity_type.dart';
import '../../l10n/app_localizations.dart';
import '../onboarding/activity_type_ui.dart';
import 'history_filter.dart';
import 'history_providers.dart';

/// Period / sort / activity / favorites filter sheet. Filters apply live via
/// [historyFilterProvider]; "Apply" just closes. Ports `FilterBottomSheet`.
class HistoryFilterSheet extends ConsumerWidget {
  const HistoryFilterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).textTheme;
    final filter = ref.watch(historyFilterProvider);
    final notifier = ref.read(historyFilterProvider.notifier);

    final periods = <(String, TimePeriod)>[
      (l10n.periodThisWeek, TimePeriod.thisWeek),
      (l10n.periodThisMonth, TimePeriod.thisMonth),
      (l10n.periodThisYear, TimePeriod.thisYear),
      (l10n.periodAll, TimePeriod.all),
    ];
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
            _SectionLabel(l10n.historySectionPeriod),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, value) in periods)
                  FilterChip(
                    selected: filter.period == value,
                    onSelected: (_) => notifier.setPeriod(value),
                    label: Text(label),
                  ),
              ],
            ),
            const SizedBox(height: 20),
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
                FilterChip(
                  selected: filter.activity == null,
                  onSelected: (_) => notifier.setActivity(null),
                  label: Text(l10n.activityAll),
                ),
                for (final type in ActivityType.values)
                  FilterChip(
                    selected: filter.activity == type,
                    onSelected: (_) => notifier.setActivity(type),
                    avatar: Icon(type.icon, size: 18),
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
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  shape: const RoundedRectangleBorder(
                      borderRadius: AppShapes.pill),
                ),
                child: Text(l10n.actionApply),
              ),
            ),
            const SizedBox(height: 16),
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
