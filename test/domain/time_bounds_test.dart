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

  test('monthRangeBounds: monthFrom omitted (monthTo=5, 2024) → defaults to Jan 1 00:00 … May 31 23:59:59.999',
      () {
    final (s, e) = monthRangeBounds(year: 2024, monthTo: 5);
    expect(DateTime.fromMillisecondsSinceEpoch(s), DateTime(2024, 1, 1));
    expect(DateTime.fromMillisecondsSinceEpoch(e),
        DateTime(2024, 5, 31, 23, 59, 59, 999));
  });

  test('monthRangeBounds: monthTo omitted (monthFrom=3, 2024) → defaults to Mar 1 00:00 … Dec 31 23:59:59.999',
      () {
    final (s, e) = monthRangeBounds(year: 2024, monthFrom: 3);
    expect(DateTime.fromMillisecondsSinceEpoch(s), DateTime(2024, 3, 1));
    expect(DateTime.fromMillisecondsSinceEpoch(e),
        DateTime(2024, 12, 31, 23, 59, 59, 999));
  });

  test('monthRangeBounds: explicit null monthFrom/monthTo behave like omitted (Feb–Dec 2023, Jan–Oct 2023)',
      () {
    expect(monthRangeBounds(year: 2023, monthFrom: 2, monthTo: null),
        monthRangeBounds(year: 2023, monthFrom: 2, monthTo: 12));
    expect(monthRangeBounds(year: 2023, monthFrom: null, monthTo: 10),
        monthRangeBounds(year: 2023, monthFrom: 1, monthTo: 10));
  });

  test('monthRangeBounds: both omitted → equals yearBounds(year:) for the same year',
      () {
    expect(monthRangeBounds(year: 2024), yearBounds(year: 2024));
  });

  test('monthOfYearInRange: month exactly on the lower bound (monthFrom) → true',
      () {
    final ms = DateTime(2024, 5, 15).millisecondsSinceEpoch;
    expect(monthOfYearInRange(ms, monthFrom: 5, monthTo: 8), isTrue);
  });

  test('monthOfYearInRange: month exactly on the upper bound (monthTo) → true',
      () {
    final ms = DateTime(2024, 8, 15).millisecondsSinceEpoch;
    expect(monthOfYearInRange(ms, monthFrom: 5, monthTo: 8), isTrue);
  });

  test('monthOfYearInRange: month strictly inside the range → true', () {
    final ms = DateTime(2024, 6, 15).millisecondsSinceEpoch;
    expect(monthOfYearInRange(ms, monthFrom: 5, monthTo: 8), isTrue);
  });

  test('monthOfYearInRange: month before monthFrom → false',
      () {
    final ms = DateTime(2024, 3, 15).millisecondsSinceEpoch;
    expect(monthOfYearInRange(ms, monthFrom: 5, monthTo: 8), isFalse);
  });

  test('monthOfYearInRange: month after monthTo → false', () {
    final ms = DateTime(2024, 10, 15).millisecondsSinceEpoch;
    expect(monthOfYearInRange(ms, monthFrom: 5, monthTo: 8), isFalse);
  });

  test('monthOfYearInRange: both bounds null → always true (unrestricted, whole year)',
      () {
    for (final month in [1, 6, 12]) {
      final ms = DateTime(2024, month, 15).millisecondsSinceEpoch;
      expect(monthOfYearInRange(ms), isTrue);
    }
  });

  test('monthOfYearInRange: only monthFrom set (monthTo defaults to December)',
      () {
    final beforeFrom = DateTime(2024, 4, 15).millisecondsSinceEpoch;
    final afterFrom = DateTime(2024, 12, 15).millisecondsSinceEpoch;
    expect(monthOfYearInRange(beforeFrom, monthFrom: 5), isFalse);
    expect(monthOfYearInRange(afterFrom, monthFrom: 5), isTrue);
  });

  test('monthOfYearInRange: only monthTo set (monthFrom defaults to January)',
      () {
    final beforeTo = DateTime(2024, 1, 15).millisecondsSinceEpoch;
    final afterTo = DateTime(2024, 9, 15).millisecondsSinceEpoch;
    expect(monthOfYearInRange(beforeTo, monthTo: 8), isTrue);
    expect(monthOfYearInRange(afterTo, monthTo: 8), isFalse);
  });

  test('monthOfYearInRange: single-month range (monthFrom == monthTo) matches only that month',
      () {
    final theMonth = DateTime(2024, 6, 15).millisecondsSinceEpoch;
    final otherMonth = DateTime(2024, 7, 15).millisecondsSinceEpoch;
    expect(monthOfYearInRange(theMonth, monthFrom: 6, monthTo: 6), isTrue);
    expect(monthOfYearInRange(otherMonth, monthFrom: 6, monthTo: 6), isFalse);
  });

  test('monthOfYearInRange: matches the same month across different years '
      '(year-independent — the whole point of the cross-year filter)', () {
    for (final year in [2019, 2024, 2031]) {
      final ms = DateTime(year, 3, 15).millisecondsSinceEpoch;
      expect(monthOfYearInRange(ms, monthFrom: 3, monthTo: 5), isTrue,
          reason: 'March $year should match monthFrom:3, monthTo:5');
    }
  });

  test('monthOfYearInRange: month boundary instants (discriminates local vs. '
      'UTC — the doc comment promises the LOCAL calendar month)', () {
    final lastInstantOfMay =
        DateTime(2024, 5, 31, 23, 59, 59, 999).millisecondsSinceEpoch;
    final firstInstantOfJune = DateTime(2024, 6, 1).millisecondsSinceEpoch;
    expect(monthOfYearInRange(lastInstantOfMay, monthFrom: 6, monthTo: 6),
        isFalse);
    expect(monthOfYearInRange(firstInstantOfJune, monthFrom: 6, monthTo: 6),
        isTrue);
  });

  test('monthOfYearInRange: an inverted range (monthFrom > monthTo) matches '
      'no month — no wrap-around across year-end', () {
    for (final month in [1, 6, 11, 12]) {
      final ms = DateTime(2024, month, 15).millisecondsSinceEpoch;
      expect(monthOfYearInRange(ms, monthFrom: 11, monthTo: 2), isFalse,
          reason: 'month $month with an inverted 11..2 range should not match');
    }
  });
}
