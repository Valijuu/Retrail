/// Inclusive `(start, end)` epoch-millisecond bounds, computed in the device's
/// local timezone. `now` is injectable for deterministic tests where a
/// function derives its window from "now" (all but [monthRangeBounds] and
/// [monthOfYearInRange], whose result is fully specified by their own
/// arguments — the latter also isn't a [Bounds] at all, but a predicate over
/// a single timestamp).
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

/// Day-of-month component for the first day of a month.
const _firstDayOfMonth = 1;

/// First of [monthFrom] 00:00:00.000 → last day of [monthTo] 23:59:59.999
/// (local), both within [year]. A missing bound defaults to the respective
/// end of the year ([monthFrom] → January, [monthTo] → December), mirroring
/// [monthOfYearInRange]. Caller guarantees `1 <= monthFrom <= monthTo <= 12`
/// when both are given.
Bounds monthRangeBounds({required int year, int? monthFrom, int? monthTo}) {
  final firstMonth = monthFrom ?? DateTime.january;
  final lastMonth = monthTo ?? DateTime.december;
  final start = DateTime(year, firstMonth, _firstDayOfMonth);
  // Month overflow (13) rolls into January of the next year.
  final endExclusive = DateTime(year, lastMonth + 1, _firstDayOfMonth);
  return (start.millisecondsSinceEpoch, endExclusive.millisecondsSinceEpoch - 1);
}

/// Whether [epochMs]'s local calendar month falls within the inclusive
/// `[monthFrom, monthTo]` range (1-12). A missing bound defaults to the
/// respective end of the year ([monthFrom] → 1, [monthTo] → 12). Used for the
/// cross-year month filter (e.g. "March–May, every year" with no year
/// selected — see `HistoryFilter.monthFrom`).
///
/// Caller guarantees `1 <= monthFrom <= monthTo <= 12` when both are given
/// (mirrors [monthRangeBounds]'s invariant) — an inverted range (e.g.
/// `monthFrom: 11, monthTo: 2` for "Nov–Feb") does NOT wrap across year-end;
/// it matches no month at all, since `month >= 11 && month <= 2` is never
/// true.
bool monthOfYearInRange(int epochMs, {int? monthFrom, int? monthTo}) {
  final month = DateTime.fromMillisecondsSinceEpoch(epochMs).month;
  return month >= (monthFrom ?? DateTime.january) &&
      month <= (monthTo ?? DateTime.december);
}

/// Jan 1 00:00:00.000 of the specified or current year → Dec 31 23:59:59.999 (local).
Bounds yearBounds({int? year, int? nowMs}) {
  final now = DateTime.fromMillisecondsSinceEpoch(_nowMs(nowMs));
  final selectedYear = year ?? now.year;
  final start = DateTime(selectedYear, DateTime.january, 1);
  final endExclusive = DateTime(selectedYear + 1, DateTime.january, 1);
  return (start.millisecondsSinceEpoch, endExclusive.millisecondsSinceEpoch - 1);
}
