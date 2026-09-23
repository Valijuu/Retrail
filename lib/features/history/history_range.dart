import '../../domain/time_bounds.dart';
import 'history_filter.dart';

/// Computes the `[start, end]` epoch-millisecond window (either bound
/// nullable = unbounded that side) that a [HistoryFilter] restricts rides to.
/// Feeds `RideRepository.getRidesWithTrackpointsInRange`.
///
/// - `f.year == null` → the existing union-of-periods logic: the earliest
///   selected period's start, with an open (`null`) end. Empty `periods`
///   means no restriction at all. The month range is only meaningful within
///   one selected year (see [HistoryFilter.monthFrom]), so it's ignored here
///   too — the UI never shows it without a year selected either.
/// - `f.year` set, month range set (`monthFrom`/`monthTo` non-null) →
///   [monthRangeBounds] for that year, defaulting the unset side to
///   Jan/Dec. On the current year with periods also selected, this narrows
///   further: the window is the *intersection* of the month range and the
///   period-adjusted window below (latest start, earliest end) — a
///   combination where the period falls outside the month range yields an
///   empty window (`start > end`) rather than silently favoring one side.
/// - `f.year` set, no month range → the full-year window from [yearBounds].
///   Week/month periods are only additionally applied (narrowing the start,
///   open end) when `f.year` is the current calendar year; for a past/future
///   year they would be inconsistent, so they're ignored (the UI hides those
///   chips in that case, see `filter_sheet.dart`).
(int? start, int? end) effectiveRange(HistoryFilter f, {int? nowMs}) {
  if (f.year != null) {
    final now = DateTime.fromMillisecondsSinceEpoch(
        nowMs ?? DateTime.now().millisecondsSinceEpoch);
    final isCurrentYear = f.year == now.year;
    final hasMonthRange = f.monthFrom != null || f.monthTo != null;

    if (hasMonthRange) {
      final monthRange = monthRangeBounds(
        year: f.year!,
        monthFrom: f.monthFrom ?? 1,
        monthTo: f.monthTo ?? 12,
      );
      if (isCurrentYear && f.periods.isNotEmpty) {
        final periodStart = _periodUnionStart(f.periods, nowMs);
        final start =
            periodStart > monthRange.$1 ? periodStart : monthRange.$1;
        final end = now.millisecondsSinceEpoch < monthRange.$2
            ? now.millisecondsSinceEpoch
            : monthRange.$2;
        return (start, end);
      }
      return monthRange;
    }

    if (isCurrentYear && f.periods.isNotEmpty) {
      return (_periodUnionStart(f.periods, nowMs), null);
    }
    return yearBounds(year: f.year, nowMs: nowMs);
  }
  if (f.periods.isEmpty) return (null, null);
  return (_periodUnionStart(f.periods, nowMs), null);
}

// Multi-select periods combine as a union — with the windows all ending
// "now" and nesting into each other, that is simply the EARLIEST selected
// start.
int _periodUnionStart(Set<TimePeriod> periods, int? nowMs) {
  int startOf(TimePeriod p) => switch (p) {
        TimePeriod.thisWeek => weekBounds(nowMs: nowMs).$1,
        TimePeriod.thisMonth => monthBounds(nowMs: nowMs).$1,
      };
  return periods.map(startOf).reduce((a, b) => a < b ? a : b);
}
