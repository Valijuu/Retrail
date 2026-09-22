import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/features/history/history_filter.dart';
import 'package:retrail/features/history/history_providers.dart';

void main() {
  group('HistoryFilterNotifier.setYear', () {
    test('sets the year', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(historyFilterProvider.notifier).setYear(2023);
      expect(c.read(historyFilterProvider).year, 2023);
    });

    test('setYear(null) resets back to "All years"', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final notifier = c.read(historyFilterProvider.notifier);
      notifier.setYear(2023);
      notifier.setYear(null);
      expect(c.read(historyFilterProvider).year, isNull);
    });

    test('setYear does not touch other filter fields', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final notifier = c.read(historyFilterProvider.notifier);
      notifier.setSort(SortOrder.distance);
      notifier.setYear(2023);
      expect(c.read(historyFilterProvider).sort, SortOrder.distance);
    });
  });

  group('activeFilterCountProvider with year', () {
    test('counts a set year', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(historyFilterProvider.notifier).setYear(2023);
      expect(c.read(activeFilterCountProvider), 1);
    });
  });
}
