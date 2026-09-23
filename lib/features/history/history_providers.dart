import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/activity_type.dart';
import '../../data/repositories/data_providers.dart';
import '../active_ride/active_ride_providers.dart';
import '../settings/settings_providers.dart';
import 'history_controller.dart';
import 'history_filter.dart';
import 'history_items.dart';
import 'history_range.dart';

/// Mutable history filter state. Mirrors the original `RideHistoryViewModel`
/// filter flows + setters.
class HistoryFilterNotifier extends Notifier<HistoryFilter> {
  @override
  HistoryFilter build() => _defaultFilter();

  /// The app's default filter: the current calendar month and year (not
  /// "All years"/unrestricted) — so the Von/Bis month range and Year
  /// dropdown both start on "now", and the filter badge starts at 0 (see
  /// `activeFilterCount`'s `nowMs` seam). Both stay explicitly changeable
  /// afterwards — "All years" via `setYear(null)`, any month range via
  /// [setMonthFrom]/[setMonthTo].
  static HistoryFilter _defaultFilter() {
    final now = DateTime.now();
    return HistoryFilter(
        year: now.year, monthFrom: now.month, monthTo: now.month);
  }

  void setSort(SortOrder s) => state = state.copyWith(sort: s);
  void setQuery(String q) => state = state.copyWith(query: q);
  void setFavoritesOnly(bool v) => state = state.copyWith(favoritesOnly: v);

  /// Adds/removes [a] from the multi-select activity set (any-of semantics).
  void toggleActivity(ActivityType a) {
    final s = {...state.activities};
    if (!s.remove(a)) s.add(a);
    state = state.copyWith(activities: s);
  }

  /// The "All" activity chip: clears the selection (= every activity).
  void clearActivities() => state = state.copyWith(activities: const {});

  /// Sets the selected calendar year, or resets to "All years" for `null`.
  /// Leaves any month range untouched — a month means the same thing
  /// regardless of year (or "All years"), see [HistoryFilter.monthFrom].
  /// Since the default month range is "this month" (see [_defaultFilter]),
  /// switching to a year other than the current one shows just that one
  /// month within the new year unless the month range is widened too — e.g.
  /// Von=January/Bis=December for the whole year (there's no "All" shortcut
  /// for the month range).
  void setYear(int? year) => state = year == null
      ? state.copyWith(clearYear: true)
      : state.copyWith(year: year);

  /// Sets the month-range start. Pulls [HistoryFilter.monthTo] up to match if
  /// it would otherwise fall before the new start (Von/Bis range picker UX).
  void setMonthFrom(int month) => state = state.copyWith(
      monthFrom: month,
      monthTo: state.monthTo != null && month > state.monthTo!
          ? month
          : state.monthTo);

  /// Sets the month-range end. Pulls [HistoryFilter.monthFrom] down to match
  /// if it would otherwise fall after the new end (Von/Bis range picker UX).
  void setMonthTo(int month) => state = state.copyWith(
      monthTo: month,
      monthFrom: state.monthFrom != null && month < state.monthFrom!
          ? month
          : state.monthFrom);

  void reset() => state = _defaultFilter();
}

final historyFilterProvider =
    NotifierProvider<HistoryFilterNotifier, HistoryFilter>(
        HistoryFilterNotifier.new);

/// Count of active non-default filters (search excluded) for the icon badge.
final activeFilterCountProvider =
    Provider<int>((ref) => activeFilterCount(ref.watch(historyFilterProvider)));

/// The filtered/sorted/date-grouped history list. Recomputes when rides or the
/// filter change. Widget tests stub this with a finite stream (Drift `.watch()`
/// never closes — see the established test rule).
final historyItemsProvider = StreamProvider<List<HistoryItem>>((ref) {
  final filter = ref.watch(historyFilterProvider);
  final locale = ref.watch(dateFormatLocaleProvider);
  final repo = ref.watch(rideRepositoryProvider);
  final (start, end) = effectiveRange(filter);
  return repo
      .getRidesInRange(startMs: start, endMs: end)
      .map((rides) => buildHistoryItems(rides, filter, locale: locale));
});

/// Distinct calendar years present in the ride history, descending (newest
/// first) — feeds the filter sheet's year picker. Derived in Dart from the
/// plain ride list (small, rarely-changing; no trackpoint join needed) rather
/// than a new SQL query. `autoDispose` so the underlying `watch()` stream
/// closes once the filter sheet (its only consumer) is no longer open.
final availableHistoryYearsProvider = StreamProvider.autoDispose<List<int>>((ref) {
  final repo = ref.watch(rideRepositoryProvider);
  return repo.getAllRides().map((rides) {
    final years = <int>{
      for (final ride in rides)
        if (ride.date != null || ride.startTime != null)
          DateTime.fromMillisecondsSinceEpoch(ride.date ?? ride.startTime!)
              .year,
    };
    return years.toList()..sort((a, b) => b.compareTo(a));
  });
});

/// Year-picker dropdown items: [availableHistoryYearsProvider]'s years,
/// always unioned with the current calendar year (so the year the app just
/// rolled into is selectable immediately, without waiting for a first ride
/// to be recorded in it — this is what replaces the old "This year" period
/// chip) and defensively unioned with the currently selected year (in case
/// its rides were just bulk-deleted and it dropped out of the DB-derived
/// list — keeps the dropdown's "exactly one item per value" assertion from
/// ever firing on a stale value, see `filter_sheet.dart`). A dedicated
/// provider rather than an inline widget computation so it only recomputes
/// when the years list or the selected year actually change, not on every
/// `HistoryFilterSheet` rebuild (e.g. toggling sort/activity/favorites no
/// longer touches this).
final yearPickerItemsProvider = Provider<List<int>>((ref) {
  final years =
      ref.watch(availableHistoryYearsProvider).asData?.value ?? const [];
  final selectedYear = ref.watch(historyFilterProvider.select((f) => f.year));
  final combined = {...years, DateTime.now().year, ?selectedYear};
  return combined.toList()..sort((a, b) => b.compareTo(a));
});

final historyControllerProvider = Provider<HistoryController>(
  (ref) => HistoryController(
    ref.watch(rideRepositoryProvider),
    ref.watch(routePreviewCacheProvider),
  ),
);
