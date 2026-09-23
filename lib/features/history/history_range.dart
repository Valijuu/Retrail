import '../../domain/time_bounds.dart';
import 'history_filter.dart';

/// Computes the `[start, end]` epoch-millisecond window (either bound
/// nullable = unbounded that side) that a [HistoryFilter] restricts rides to.
/// Feeds `RideRepository.getRidesWithTrackpointsInRange`.
///
/// - `f.year == null` ("All years") → unrestricted (`null, null`). The month
///   range is deliberately ignored here — it becomes a cross-year "these
///   months, every year" filter instead (see [HistoryFilter.monthFrom]),
///   which can't be expressed as a single `(start, end)` window; that
///   restriction is applied later, in `buildHistoryItems` (in-memory, via
///   `monthOfYearInRange`).
/// - `f.year` set, month range set (`monthFrom`/`monthTo` non-null) →
///   [monthRangeBounds] for that year, defaulting an unset side to Jan/Dec.
/// - `f.year` set, no month range → the full-year window from [yearBounds].
///
/// Every value `f` carries is already concrete (no "now"-dependent
/// fallback), so unlike its `lib/domain/time_bounds.dart` building blocks,
/// this function takes no injectable `nowMs`.
(int? start, int? end) effectiveRange(HistoryFilter f) {
  if (f.year == null) return (null, null);
  final hasMonthRange = f.monthFrom != null || f.monthTo != null;
  if (hasMonthRange) {
    return monthRangeBounds(
      year: f.year!,
      monthFrom: f.monthFrom ?? 1,
      monthTo: f.monthTo ?? 12,
    );
  }
  return yearBounds(year: f.year);
}
