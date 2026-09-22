/// Inclusive `(start, end)` epoch-millisecond bounds, computed in the device's
/// local timezone. `now` is injectable for deterministic tests where a
/// function derives its window from "now" (all but [monthRangeBounds], whose
/// window is fully specified by its `year`/`monthFrom`/`monthTo` arguments).
typedef Bounds = (int start, int end);

int _nowMs(int? nowMs) => nowMs ?? DateTime.now().millisecondsSinceEpoch;

/// Number of days in a calendar week, used to compute week boundaries.
const _daysInWeek = 7;

/// Today 00:00:00.000 → 23:59:59.999 (local).
Bounds dayBounds({int? nowMs}) {
  final now = DateTime.fromMillisecondsSinceEpoch(_nowMs(nowMs));
  final start = DateTime(now.year, now.month, now.day);
  final endExclusive = DateTime(now.year, now.month, now.day + 1);
  return (start.millisecondsSinceEpoch, endExclusive.millisecondsSinceEpoch - 1);
}

/// Monday 00:00:00.000 → Sunday 23:59:59.999 of the current week (local).
Bounds weekBounds({int? nowMs}) {
  final now = DateTime.fromMillisecondsSinceEpoch(_nowMs(nowMs));
  // DateTime.weekday: Mon=1 … Sun=7, so Mon→0 … Sun→6.
  final daysFromMonday = (now.weekday - DateTime.monday) % _daysInWeek;
  final start = DateTime(now.year, now.month, now.day - daysFromMonday);
  final endExclusive =
      DateTime(start.year, start.month, start.day + _daysInWeek);
  return (start.millisecondsSinceEpoch, endExclusive.millisecondsSinceEpoch - 1);
}

/// First of the current month 00:00:00.000 → last day 23:59:59.999 (local).
///
/// A single-month case of [monthRangeBounds], for the month containing `now`.
Bounds monthBounds({int? nowMs}) {
  final now = DateTime.fromMillisecondsSinceEpoch(_nowMs(nowMs));
  return monthRangeBounds(
      year: now.year, monthFrom: now.month, monthTo: now.month);
}

/// First of [monthFrom] 00:00:00.000 → last day of [monthTo] 23:59:59.999
/// (local), both within [year]. Caller guarantees `1 <= monthFrom <= monthTo
/// <= 12`.
Bounds monthRangeBounds(
    {required int year, required int monthFrom, required int monthTo}) {
  final start = DateTime(year, monthFrom, 1);
  final endExclusive = DateTime(year, monthTo + 1, 1);
  return (start.millisecondsSinceEpoch, endExclusive.millisecondsSinceEpoch - 1);
}

/// Jan 1 00:00:00.000 of the specified or current year → Dec 31 23:59:59.999 (local).
Bounds yearBounds({int? year, int? nowMs}) {
  final now = DateTime.fromMillisecondsSinceEpoch(_nowMs(nowMs));
  final selectedYear = year ?? now.year;
  final start = DateTime(selectedYear, 1, 1);
  final endExclusive = DateTime(selectedYear + 1, 1, 1);
  return (start.millisecondsSinceEpoch, endExclusive.millisecondsSinceEpoch - 1);
}
