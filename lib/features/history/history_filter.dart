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

  HistoryFilter copyWith({
    Set<TimePeriod>? periods,
    SortOrder? sort,
    String? query,
    bool? favoritesOnly,
    Set<ActivityType>? activities,
    int? year,
    bool clearYear = false,
  }) =>
      HistoryFilter(
        periods: periods ?? this.periods,
        sort: sort ?? this.sort,
        query: query ?? this.query,
        favoritesOnly: favoritesOnly ?? this.favoritesOnly,
        activities: activities ?? this.activities,
        year: clearYear ? null : (year ?? this.year),
      );

  @override
  bool operator ==(Object other) =>
      other is HistoryFilter &&
      _setEq.equals(other.periods, periods) &&
      other.sort == sort &&
      other.query == query &&
      other.favoritesOnly == favoritesOnly &&
      _setEq.equals(other.activities, activities) &&
      other.year == year;

  @override
  int get hashCode => Object.hash(_setEq.hash(periods), sort, query,
      favoritesOnly, _setEq.hash(activities), year);
}

/// Count of active, non-default filter sections for the filter-icon badge. The
/// search query is excluded (it has its own visible bar). Mirrors
/// `activeFilterCount`.
int activeFilterCount(HistoryFilter f) {
  var count = 0;
  if (f.periods.isNotEmpty) count++;
  if (f.sort != SortOrder.date) count++;
  if (f.favoritesOnly) count++;
  if (f.activities.isNotEmpty) count++;
  if (f.year != null) count++;
  return count;
}

/// Whether any non-default filter (search included) is active. Mirrors
/// `isFilterActive`.
bool isFilterActive(HistoryFilter f) =>
    f.periods.isNotEmpty ||
    f.sort != SortOrder.date ||
    f.query.isNotEmpty ||
    f.favoritesOnly ||
    f.activities.isNotEmpty ||
    f.year != null;
