import '../../domain/activity_type.dart';

/// Time-window chips for the history filter. Mirrors the original `TimePeriod`.
enum TimePeriod { thisWeek, thisMonth, thisYear, all }

/// Sort-order chips for the history filter. Mirrors the original `SortOrder`.
enum SortOrder { date, distance, speed, duration }

/// Immutable bundle of the history filter state (period, sort, search, favorites
/// and activity type). Mirrors `RideHistoryViewModel`'s five filter flows.
class HistoryFilter {
  const HistoryFilter({
    this.period = TimePeriod.all,
    this.sort = SortOrder.date,
    this.query = '',
    this.favoritesOnly = false,
    this.activity,
  });

  final TimePeriod period;
  final SortOrder sort;
  final String query;
  final bool favoritesOnly;
  final ActivityType? activity;

  HistoryFilter copyWith({
    TimePeriod? period,
    SortOrder? sort,
    String? query,
    bool? favoritesOnly,
    ActivityType? activity,
    bool clearActivity = false,
  }) =>
      HistoryFilter(
        period: period ?? this.period,
        sort: sort ?? this.sort,
        query: query ?? this.query,
        favoritesOnly: favoritesOnly ?? this.favoritesOnly,
        activity: clearActivity ? null : (activity ?? this.activity),
      );

  @override
  bool operator ==(Object other) =>
      other is HistoryFilter &&
      other.period == period &&
      other.sort == sort &&
      other.query == query &&
      other.favoritesOnly == favoritesOnly &&
      other.activity == activity;

  @override
  int get hashCode => Object.hash(period, sort, query, favoritesOnly, activity);
}

/// Count of active, non-default filters for the filter-icon badge. The search
/// query is excluded (it has its own visible bar). Mirrors `activeFilterCount`.
int activeFilterCount(HistoryFilter f) {
  var count = 0;
  if (f.period != TimePeriod.all) count++;
  if (f.sort != SortOrder.date) count++;
  if (f.favoritesOnly) count++;
  if (f.activity != null) count++;
  return count;
}

/// Whether any non-default filter (search included) is active. Mirrors
/// `isFilterActive`.
bool isFilterActive(HistoryFilter f) =>
    f.period != TimePeriod.all ||
    f.sort != SortOrder.date ||
    f.query.isNotEmpty ||
    f.favoritesOnly ||
    f.activity != null;
