import 'package:collection/collection.dart';

import '../../domain/activity_type.dart';

/// Time-window chips for the history filter. Mirrors the original `TimePeriod`;
/// "all time" is no longer an enum member — it is the **empty selection** (see
/// [HistoryFilter.periods]).
enum TimePeriod { thisWeek, thisMonth }

/// Sort-order chips for the history filter. Mirrors the original `SortOrder`.
enum SortOrder { date, distance, speed, duration }

const _setEq = SetEquality<Object>();

/// Immutable bundle of the history filter state (periods, sort, search,
/// favorites and activities). Periods and activities are **multi-select** sets:
/// a ride matches when it falls in ANY selected period and has ANY selected
/// activity; an empty set means "no restriction" (the "All" chip).
class HistoryFilter {
  const HistoryFilter({
    this.periods = const {},
    this.sort = SortOrder.date,
    this.query = '',
    this.favoritesOnly = false,
    this.activities = const {},
    this.year,
    this.monthFrom,
    this.monthTo,
  });

  /// Selected time windows, combined as a union. Empty = all time.
  final Set<TimePeriod> periods;
  final SortOrder sort;
  final String query;
  final bool favoritesOnly;

  /// Selected activity types (any-of). Empty = all activities.
  final Set<ActivityType> activities;

  /// Selected calendar year, or `null` for "All years" (unrestricted).
  final int? year;

  /// Start/end month (1-12, inclusive) of the month-range filter. `null` on
  /// either side means "no restriction on that side" (the dropdown shows
  /// January/December respectively). With [year] set, restricts to that
  /// month range within that one year; with [year] `null` ("All years"), it
  /// becomes a cross-year filter — e.g. March–May matches every March
  /// through May, in every year (see `monthOfYearInRange`).
  final int? monthFrom;
  final int? monthTo;

  HistoryFilter copyWith({
    Set<TimePeriod>? periods,
    SortOrder? sort,
    String? query,
    bool? favoritesOnly,
    Set<ActivityType>? activities,
    int? year,
    bool clearYear = false,
    int? monthFrom,
    bool clearMonthFrom = false,
    int? monthTo,
    bool clearMonthTo = false,
  }) =>
      HistoryFilter(
        periods: periods ?? this.periods,
        sort: sort ?? this.sort,
        query: query ?? this.query,
        favoritesOnly: favoritesOnly ?? this.favoritesOnly,
        activities: activities ?? this.activities,
        year: clearYear ? null : (year ?? this.year),
        monthFrom: clearMonthFrom ? null : (monthFrom ?? this.monthFrom),
        monthTo: clearMonthTo ? null : (monthTo ?? this.monthTo),
      );

  @override
  bool operator ==(Object other) =>
      other is HistoryFilter &&
      _setEq.equals(other.periods, periods) &&
      other.sort == sort &&
      other.query == query &&
      other.favoritesOnly == favoritesOnly &&
      _setEq.equals(other.activities, activities) &&
      other.year == year &&
      other.monthFrom == monthFrom &&
      other.monthTo == monthTo;

  @override
  int get hashCode => Object.hash(_setEq.hash(periods), sort, query,
      favoritesOnly, _setEq.hash(activities), year, monthFrom, monthTo);
}

/// Count of active, non-default filter sections for the filter-icon badge. The
/// search query is excluded (it has its own visible bar). Mirrors
/// `activeFilterCount`.
///
/// [nowYear] is the injectable "current calendar year" seam (mirrors the
/// `nowMs` pattern in `time_bounds.dart`/`history_range.dart`) — the app's
/// default filter state is now "this year" (see `HistoryFilterNotifier`), so
/// `f.year` matching the current year is the non-active baseline, not `null`.
int activeFilterCount(HistoryFilter f, {int? nowYear}) {
  final currentYear = nowYear ?? DateTime.now().year;
  var count = 0;
  if (f.periods.isNotEmpty) count++;
  if (f.sort != SortOrder.date) count++;
  if (f.favoritesOnly) count++;
  if (f.activities.isNotEmpty) count++;
  if (f.year != currentYear) count++;
  if (f.monthFrom != null || f.monthTo != null) count++;
  return count;
}

/// Whether any non-default filter (search included) is active. Mirrors
/// `isFilterActive`. See [activeFilterCount] for [nowYear].
bool isFilterActive(HistoryFilter f, {int? nowYear}) =>
    f.periods.isNotEmpty ||
    f.sort != SortOrder.date ||
    f.query.isNotEmpty ||
    f.favoritesOnly ||
    f.activities.isNotEmpty ||
    f.year != (nowYear ?? DateTime.now().year) ||
    f.monthFrom != null ||
    f.monthTo != null;
