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
    // The app's actual default is now "this year" (see HistoryFilterNotifier),
    // not "All years" — so activeFilterCount/isFilterActive must know the
    // current calendar year to tell "still on the default" apart from "the
    // user picked a year". `nowYear` is the injectable seam for that (mirrors
    // the `nowMs` pattern in time_bounds.dart/history_range.dart).
    test('activeFilterCount counts a year that does not match nowYear', () {
      const f = HistoryFilter(year: 2023);
      expect(activeFilterCount(f, nowYear: 2020), 1);
    });

    test('activeFilterCount combines a non-matching year with other active filters', () {
      const f = HistoryFilter(
        year: 2023,
        periods: {TimePeriod.thisWeek},
        favoritesOnly: true,
      );
      expect(activeFilterCount(f, nowYear: 2020), 3);
    });

    test('isFilterActive is true when year does not match nowYear', () {
      expect(
          isFilterActive(const HistoryFilter(year: 2023), nowYear: 2020),
          isTrue);
    });

    test('activeFilterCount does not count a year that matches nowYear (the app default)', () {
      const f = HistoryFilter(year: 2024);
      expect(activeFilterCount(f, nowYear: 2024), 0);
    });

    test('isFilterActive is false when year matches nowYear and nothing else is set', () {
      expect(
          isFilterActive(const HistoryFilter(year: 2024), nowYear: 2024),
          isFalse);
    });

    test('year == null ("All years") counts as active regardless of nowYear', () {
      expect(activeFilterCount(const HistoryFilter(), nowYear: 2024), 1);
      expect(isFilterActive(const HistoryFilter(), nowYear: 2024), isTrue);
    });

    test('without nowYear, falls back to the real current calendar year', () {
      final currentYear = DateTime.now().year;
      expect(activeFilterCount(HistoryFilter(year: currentYear)), 0);
      expect(isFilterActive(HistoryFilter(year: currentYear)), isFalse);
    });
  });

  group('month range fields', () {
    test('monthFrom and monthTo default to null (no restriction)', () {
      expect(const HistoryFilter().monthFrom, isNull);
      expect(const HistoryFilter().monthTo, isNull);
    });

    test('copyWith sets monthFrom and monthTo', () {
      const f = HistoryFilter();
      final updated = f.copyWith(monthFrom: 6, monthTo: 8);
      expect(updated.monthFrom, 6);
      expect(updated.monthTo, 8);
    });

    test('copyWith without monthFrom/monthTo leaves them unchanged', () {
      const f = HistoryFilter(monthFrom: 6, monthTo: 8);
      final updated = f.copyWith(sort: SortOrder.distance);
      expect(updated.monthFrom, 6);
      expect(updated.monthTo, 8);
    });

    test('copyWith clearMonthFrom resets monthFrom to null, monthTo untouched', () {
      const f = HistoryFilter(monthFrom: 6, monthTo: 8);
      final updated = f.copyWith(clearMonthFrom: true);
      expect(updated.monthFrom, isNull);
      expect(updated.monthTo, 8);
    });

    test('copyWith clearMonthTo resets monthTo to null, monthFrom untouched', () {
      const f = HistoryFilter(monthFrom: 6, monthTo: 8);
      final updated = f.copyWith(clearMonthTo: true);
      expect(updated.monthFrom, 6);
      expect(updated.monthTo, isNull);
    });

    test('copyWith clearMonthFrom/clearMonthTo win over passed values', () {
      const f = HistoryFilter(monthFrom: 6, monthTo: 8);
      final updated = f.copyWith(
          monthFrom: 3, monthTo: 5, clearMonthFrom: true, clearMonthTo: true);
      expect(updated.monthFrom, isNull);
      expect(updated.monthTo, isNull);
    });

    test('equality and hashCode include monthFrom/monthTo', () {
      const a = HistoryFilter(monthFrom: 6, monthTo: 8);
      const b = HistoryFilter(monthFrom: 6, monthTo: 8);
      const c = HistoryFilter(monthFrom: 6, monthTo: 9);
      const d = HistoryFilter();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
      expect(a == d, isFalse);
    });
  });

  group('filter badges with month range', () {
    test('activeFilterCount counts a set month range as a single active filter', () {
      const f = HistoryFilter(year: 2023, monthFrom: 6, monthTo: 8);
      expect(activeFilterCount(f, nowYear: 2020), 2);
    });

    test('activeFilterCount counts monthFrom alone (monthTo still null) as active', () {
      const f = HistoryFilter(year: 2023, monthFrom: 6);
      expect(activeFilterCount(f, nowYear: 2020), 2);
    });

    test('isFilterActive is true when only a month range is set (year matches nowYear)', () {
      const f = HistoryFilter(year: 2024, monthFrom: 6, monthTo: 8);
      expect(isFilterActive(f, nowYear: 2024), isTrue);
    });

    test('isFilterActive is false when year matches nowYear and no month range is set', () {
      const f = HistoryFilter(year: 2024);
      expect(isFilterActive(f, nowYear: 2024), isFalse);
    });
  });
}
