import 'package:collection/collection.dart';

import '../../domain/activity_type.dart';

/// Sort-order chips for the history filter. Mirrors the original `SortOrder`.
enum SortOrder { date, distance, speed, duration }

const _setEq = SetEquality<Object>();

/// Immutable bundle of the history filter state (year, month range, sort,
/// search, favorites and activities). Activities are a **multi-select**
/// set: a ride matches when it has ANY selected activity; an empty set
/// means "no restriction" (the "All" chip).
class HistoryFilter {
  const HistoryFilter({
    this.sort = SortOrder.date,
    this.query = '',
    this.favoritesOnly = false,
    this.activities = const {},
    this.year,
    this.monthFrom,
    this.monthTo,
  });

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
      other.sort == sort &&
      other.query == query &&
      other.favoritesOnly == favoritesOnly &&
      _setEq.equals(other.activities, activities) &&
      other.year == year &&
      other.monthFrom == monthFrom &&
      other.monthTo == monthTo;

  @override
  int get hashCode => Object.hash(
      sort, query, favoritesOnly, _setEq.hash(activities), year, monthFrom, monthTo);
}

/// Count of active, non-default filter sections for the filter-icon badge. The
/// search query is excluded (it has its own visible bar). Mirrors
/// `activeFilterCount`.
///
/// The app's default filter state is "All years"/unrestricted (see
/// `HistoryFilterNotifier._defaultFilter`), so a set `year` or a set
/// `monthFrom`/`monthTo` is itself the deviation from the baseline — no
/// "now" reference needed.
int activeFilterCount(HistoryFilter f) {
  var count = 0;
  if (f.sort != SortOrder.date) count++;
  if (f.favoritesOnly) count++;
  if (f.activities.isNotEmpty) count++;
  if (f.year != null) count++;
  if (f.monthFrom != null || f.monthTo != null) count++;
  return count;
}
