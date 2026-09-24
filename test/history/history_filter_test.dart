import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/features/history/history_filter.dart';

// 2024-06-12 12:00 (fixed reference, matches history_range_test.dart /
// history_items_test.dart).
const _nowYear = 2024;
const _nowMonth = 6;

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
    // The app's default is "All years"/unrestricted (see
    // HistoryFilterNotifier) — activeFilterCount treats any
    // set year as a deviation from that default, no "now" reference needed.
    test('activeFilterCount counts a set year', () {
      const f =
          HistoryFilter(year: 2020, monthFrom: _nowMonth, monthTo: _nowMonth);
      expect(activeFilterCount(f), 2);
    });

    test('activeFilterCount combines a set year with other active filters', () {
      const f = HistoryFilter(
        year: 2020,
        monthFrom: _nowMonth,
        monthTo: _nowMonth,
        favoritesOnly: true,
      );
      expect(activeFilterCount(f), 3);
    });

    test('activeFilterCount is 0 for the unrestricted default (year and '
        'month range both null)', () {
      const f = HistoryFilter();
      expect(activeFilterCount(f), 0);
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
    test('activeFilterCount counts a set month range as active', () {
      const f = HistoryFilter(year: _nowYear, monthFrom: 3, monthTo: 5);
      expect(activeFilterCount(f), 2);
    });

    test('activeFilterCount counts monthFrom alone as active', () {
      const f = HistoryFilter(monthFrom: 3);
      expect(activeFilterCount(f), 1);
    });
  });
}
