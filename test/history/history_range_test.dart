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
  });
}
