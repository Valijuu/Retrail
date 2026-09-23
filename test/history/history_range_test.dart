import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/time_bounds.dart';
import 'package:retrail/features/history/history_filter.dart';
import 'package:retrail/features/history/history_range.dart';

// 2024-06-12 12:00 (fixed reference, matches history_items_test.dart).
const _now = 1718193600000;

void main() {
  group('effectiveRange', () {
    test('no periods, no year -> unrestricted (null, null)', () {
      expect(effectiveRange(const HistoryFilter(), nowMs: _now), (null, null));
    });

    test('single period -> start of that period, open end', () {
      final (start, end) = effectiveRange(
          const HistoryFilter(periods: {TimePeriod.thisWeek}),
          nowMs: _now);
      expect(start, weekBounds(nowMs: _now).$1);
      expect(end, isNull);
    });

    test('multiple periods union to the earliest start, open end', () {
      final (start, end) = effectiveRange(
          const HistoryFilter(
              periods: {TimePeriod.thisWeek, TimePeriod.thisMonth}),
          nowMs: _now);
      expect(start, monthBounds(nowMs: _now).$1);
      expect(end, isNull);
    });

    test('year set -> that year\'s full (start, end) bounds', () {
      final range = effectiveRange(const HistoryFilter(year: 2023), nowMs: _now);
      expect(range, yearBounds(year: 2023, nowMs: _now));
    });

    test('year set to a past year ignores week/month periods', () {
      final range = effectiveRange(
          const HistoryFilter(year: 2023, periods: {TimePeriod.thisWeek}),
          nowMs: _now);
      expect(range, yearBounds(year: 2023, nowMs: _now));
    });

    test('year set to the current calendar year still honors periods', () {
      // _now is in 2024, so year: 2024 IS the current calendar year.
      final (start, end) = effectiveRange(
          const HistoryFilter(year: 2024, periods: {TimePeriod.thisWeek}),
          nowMs: _now);
      expect(start, weekBounds(nowMs: _now).$1);
      expect(end, isNull);
    });

    test('current year with no periods still yields the full-year bounds', () {
      final range =
          effectiveRange(const HistoryFilter(year: 2024), nowMs: _now);
      expect(range, yearBounds(year: 2024, nowMs: _now));
    });

    test('month range set, current year, no periods -> monthRangeBounds directly', () {
      final range = effectiveRange(
          const HistoryFilter(year: 2024, monthFrom: 3, monthTo: 5),
          nowMs: _now);
      expect(range, monthRangeBounds(year: 2024, monthFrom: 3, monthTo: 5));
    });

    test('month range set, past year -> monthRangeBounds for that year', () {
      final range = effectiveRange(
          const HistoryFilter(year: 2023, monthFrom: 3, monthTo: 5),
          nowMs: _now);
      expect(range, monthRangeBounds(year: 2023, monthFrom: 3, monthTo: 5));
    });

    test('month range + period, current year -> intersection (later start, earlier end)', () {
      // Period "this month" (June 2024) starts later than the month range's
      // May start, and ends "now" — earlier than the month range's July end.
      final (start, end) = effectiveRange(
          const HistoryFilter(
              year: 2024,
              periods: {TimePeriod.thisMonth},
              monthFrom: 5,
              monthTo: 7),
          nowMs: _now);
      expect(start, monthBounds(nowMs: _now).$1);
      expect(end, _now);
    });

    test('month range + period, current year, contradictory combination -> empty window', () {
      // Period "this month" (June 2024) starts after the Jan-Mar month
      // range's end — the intersection is empty (start > end), not a crash
      // or a silent preference for one side.
      final (start, end) = effectiveRange(
          const HistoryFilter(
              year: 2024,
              periods: {TimePeriod.thisMonth},
              monthFrom: 1,
              monthTo: 3),
          nowMs: _now);
      expect(start! > end!, isTrue);
    });

    test('month range ignored when no year is selected', () {
      final range = effectiveRange(
          const HistoryFilter(monthFrom: 3, monthTo: 5), nowMs: _now);
      expect(range, (null, null));
    });
  });
}
