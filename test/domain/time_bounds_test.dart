import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/time_bounds.dart';

void main() {
  test('weekBounds: Monday 00:00 → Sunday 23:59:59.999', () {
    final now = DateTime(2026, 6, 17, 12, 30);
    final (s, e) = weekBounds(nowMs: now.millisecondsSinceEpoch);
    final start = DateTime.fromMillisecondsSinceEpoch(s);
    final end = DateTime.fromMillisecondsSinceEpoch(e);

    expect(start.weekday, DateTime.monday);
    expect([start.hour, start.minute, start.second, start.millisecond],
        [0, 0, 0, 0]);
    expect(end.weekday, DateTime.sunday);
    expect(e - s, const Duration(days: 7).inMilliseconds - 1);
    expect(s <= now.millisecondsSinceEpoch, isTrue);
    expect(now.millisecondsSinceEpoch <= e, isTrue);
  });

  test('Sunday belongs to the week ending that Sunday', () {
    var d = DateTime(2026, 6, 21, 23, 0);
    while (d.weekday != DateTime.sunday) {
      d = d.add(const Duration(days: 1));
    }
    final (s, e) = weekBounds(nowMs: d.millisecondsSinceEpoch);
    expect(DateTime.fromMillisecondsSinceEpoch(s),
        DateTime(d.year, d.month, d.day - 6));
    expect(d.millisecondsSinceEpoch <= e, isTrue);
  });

  test('dayBounds: midnight → 23:59:59.999', () {
    final now = DateTime(2026, 6, 17, 8, 15);
    final (s, e) = dayBounds(nowMs: now.millisecondsSinceEpoch);
    expect(DateTime.fromMillisecondsSinceEpoch(s), DateTime(2026, 6, 17));
    expect(e - s, const Duration(days: 1).inMilliseconds - 1);
  });

  test('monthBounds: first of month 00:00 → last day 23:59:59.999', () {
    final now = DateTime(2026, 6, 17, 8, 15);
    final (s, e) = monthBounds(nowMs: now.millisecondsSinceEpoch);
    expect(DateTime.fromMillisecondsSinceEpoch(s), DateTime(2026, 6, 1));
    expect(DateTime.fromMillisecondsSinceEpoch(e + 1), DateTime(2026, 7, 1));
    expect(s <= now.millisecondsSinceEpoch, isTrue);
    expect(now.millisecondsSinceEpoch <= e, isTrue);
  });

  test('monthBounds: December delegates correctly through monthRangeBounds (no rollover)', () {
    final now = DateTime(2025, 12, 15);
    expect(monthBounds(nowMs: now.millisecondsSinceEpoch),
        monthRangeBounds(year: 2025, monthFrom: 12, monthTo: 12));
  });

  test('yearBounds: Jan 1 → Dec 31 23:59:59.999 for current year when year not provided', () {
    final now = DateTime(2026, 6, 17);
    final (s, e) = yearBounds(nowMs: now.millisecondsSinceEpoch);
    expect(DateTime.fromMillisecondsSinceEpoch(s), DateTime(2026, 1, 1));
    expect(DateTime.fromMillisecondsSinceEpoch(e), DateTime(2026, 12, 31, 23, 59, 59, 999));
  });

  test('yearBounds: interval excludes timestamps from following year', () {
    final jan1Next = DateTime(2027, 1, 1).millisecondsSinceEpoch;
    final now = DateTime(2026, 6, 17);
    final (s, e) = yearBounds(nowMs: now.millisecondsSinceEpoch);
    expect(e < jan1Next, isTrue);
  });

  test('yearBounds: interval length is correct for current year', () {
    final now = DateTime(2026, 6, 17);
    final (s, e) = yearBounds(nowMs: now.millisecondsSinceEpoch);
    expect(e - s, const Duration(days: 365).inMilliseconds - 1);
  });

  test('yearBounds: accepts year parameter for past years', () {
    final (s, e) = yearBounds(year: 2024);
    expect(DateTime.fromMillisecondsSinceEpoch(s), DateTime(2024, 1, 1));
    expect(DateTime.fromMillisecondsSinceEpoch(e), DateTime(2024, 12, 31, 23, 59, 59, 999));
  });

  test('yearBounds: leap year (2024) interval length is correct', () {
    final (s, e) = yearBounds(year: 2024);
    expect(e - s, const Duration(days: 366).inMilliseconds - 1);
  });

  test('monthRangeBounds: single month (March 2024) → Mar 1 00:00 to Mar 31 23:59:59.999',
      () {
    final (s, e) = monthRangeBounds(year: 2024, monthFrom: 3, monthTo: 3);
    expect(DateTime.fromMillisecondsSinceEpoch(s), DateTime(2024, 3, 1));
    expect(DateTime.fromMillisecondsSinceEpoch(e),
        DateTime(2024, 3, 31, 23, 59, 59, 999));
  });

  test('monthRangeBounds: multi-month range (Feb–Apr 2023) → Feb 1 00:00 to Apr 30 23:59:59.999',
      () {
    final (s, e) = monthRangeBounds(year: 2023, monthFrom: 2, monthTo: 4);
    expect(DateTime.fromMillisecondsSinceEpoch(s), DateTime(2023, 2, 1));
    expect(DateTime.fromMillisecondsSinceEpoch(e),
        DateTime(2023, 4, 30, 23, 59, 59, 999));
  });

  test('monthRangeBounds: monthFrom=1 → start is Jan 1 00:00:00.000 of the year',
      () {
    final (s, _) = monthRangeBounds(year: 2025, monthFrom: 1, monthTo: 6);
    expect(DateTime.fromMillisecondsSinceEpoch(s), DateTime(2025, 1, 1));
  });

  test('monthRangeBounds: monthTo=12 → end is Dec 31 23:59:59.999, no rollover into next year',
      () {
    final (_, e) = monthRangeBounds(year: 2025, monthFrom: 6, monthTo: 12);
    expect(DateTime.fromMillisecondsSinceEpoch(e),
        DateTime(2025, 12, 31, 23, 59, 59, 999));
  });

  test('monthRangeBounds: range ending in leap-year February (2024) → Feb 29 23:59:59.999 (29 days)',
      () {
    final (_, e) = monthRangeBounds(year: 2024, monthFrom: 1, monthTo: 2);
    expect(DateTime.fromMillisecondsSinceEpoch(e),
        DateTime(2024, 2, 29, 23, 59, 59, 999));
  });

  test('monthRangeBounds: range ending in non-leap-year February (2023) → Feb 28 23:59:59.999 (28 days)',
      () {
    final (_, e) = monthRangeBounds(year: 2023, monthFrom: 1, monthTo: 2);
    expect(DateTime.fromMillisecondsSinceEpoch(e),
        DateTime(2023, 2, 28, 23, 59, 59, 999));
  });

  test('monthRangeBounds: monthFrom=1, monthTo=12 equals yearBounds(year:) for the same year',
      () {
    expect(monthRangeBounds(year: 2024, monthFrom: 1, monthTo: 12),
        yearBounds(year: 2024));
  });
}
