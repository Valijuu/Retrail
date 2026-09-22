import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/features/history/history_filter.dart';

void main() {
  group('year field', () {
    test('defaults to null (all years)', () {
      expect(const HistoryFilter().year, isNull);
    });

    test('copyWith sets year', () {
      const f = HistoryFilter();
      expect(f.copyWith(year: 2023).year, 2023);
    });

    test('copyWith without year leaves it unchanged', () {
      const f = HistoryFilter(year: 2023);
      expect(f.copyWith(sort: SortOrder.distance).year, 2023);
    });

    test('copyWith clearYear resets year to null', () {
      const f = HistoryFilter(year: 2023);
      expect(f.copyWith(clearYear: true).year, isNull);
    });

    test('copyWith clearYear wins over a passed year', () {
      const f = HistoryFilter(year: 2023);
      expect(f.copyWith(year: 2024, clearYear: true).year, isNull);
    });

    test('equality and hashCode include year', () {
      const a = HistoryFilter(year: 2023);
      const b = HistoryFilter(year: 2023);
      const c = HistoryFilter(year: 2024);
      const d = HistoryFilter();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
      expect(a == d, isFalse);
    });
  });

  group('filter badges with year', () {
    test('activeFilterCount counts a set year', () {
      const f = HistoryFilter(year: 2023);
      expect(activeFilterCount(f), 1);
    });

    test('activeFilterCount combines year with other active filters', () {
      const f = HistoryFilter(
        year: 2023,
        periods: {TimePeriod.thisWeek},
        favoritesOnly: true,
      );
      expect(activeFilterCount(f), 3);
    });

    test('isFilterActive is true when only year is set', () {
      expect(isFilterActive(const HistoryFilter(year: 2023)), isTrue);
    });

    test('isFilterActive is false for the default filter', () {
      expect(isFilterActive(const HistoryFilter()), isFalse);
    });
  });
}
