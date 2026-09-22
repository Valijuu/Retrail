import '../../domain/time_bounds.dart';
import 'history_filter.dart';

/// Computes the `[start, end]` epoch-millisecond window (either bound
/// nullable = unbounded that side) that a [HistoryFilter] restricts rides to.
/// Feeds `RideRepository.getRidesWithTrackpointsInRange`.
///
/// - `f.year` set → the full-year window from [yearBounds]. Week/month
///   periods are only additionally applied (narrowing the start, open end —
///   same as the no-year case below) when `f.year` is the current calendar
///   year; for a past/future year they would be inconsistent, so they're
///   ignored (the UI hides those chips in that case, see Task 4).
/// - `f.year == null` → the existing union-of-periods logic: the earliest
///   selected period's start, with an open (`null`) end. Empty `periods`
///   means no restriction at all.
(int? start, int? end) effectiveRange(HistoryFilter f, {int? nowMs}) {
  if (f.year != null) {
    final now = DateTime.fromMillisecondsSinceEpoch(
        nowMs ?? DateTime.now().millisecondsSinceEpoch);
    final isCurrentYear = f.year == now.year;
    if (isCurrentYear && f.periods.isNotEmpty) {
      return (_periodUnionStart(f.periods, nowMs), null);
    }
    final (start, end) = yearBounds(year: f.year, nowMs: nowMs);
    return (start, end);
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
        TimePeriod.thisYear => yearBounds(nowMs: nowMs).$1,
      };
  return periods.map(startOf).reduce((a, b) => a < b ? a : b);
}
