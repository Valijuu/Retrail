import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/time_bounds.dart';
import 'package:retrail/features/history/history_filter.dart';
import 'package:retrail/features/history/history_range.dart';

void main() {
  group('effectiveRange', () {
    test('no year -> unrestricted (null, null)', () {
      expect(effectiveRange(const HistoryFilter()), (null, null));
    });

    test('year set, no month range -> that year\'s full (start, end) bounds', () {
      final range = effectiveRange(const HistoryFilter(year: 2023));
      expect(range, yearBounds(year: 2023));
    });

    test('year set, month range set -> monthRangeBounds directly', () {
      final range = effectiveRange(
          const HistoryFilter(year: 2024, monthFrom: 3, monthTo: 5));
      expect(range, monthRangeBounds(year: 2024, monthFrom: 3, monthTo: 5));
    });

    test('year set, only monthFrom set -> monthTo defaults to December', () {
      final range =
          effectiveRange(const HistoryFilter(year: 2024, monthFrom: 3));
      expect(range, monthRangeBounds(year: 2024, monthFrom: 3, monthTo: 12));
    });

    test('year set, only monthTo set -> monthFrom defaults to January', () {
      final range =
          effectiveRange(const HistoryFilter(year: 2024, monthTo: 5));
      expect(range, monthRangeBounds(year: 2024, monthFrom: 1, monthTo: 5));
    });

    test('month range ignored when no year is selected (cross-year filter '
        'is applied later, in buildHistoryItems)', () {
      final range =
          effectiveRange(const HistoryFilter(monthFrom: 3, monthTo: 5));
      expect(range, (null, null));
    });
  });
}
