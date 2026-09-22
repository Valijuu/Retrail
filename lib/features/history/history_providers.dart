import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/activity_type.dart';
import '../../data/repositories/data_providers.dart';
import '../../tracking/tracking_providers.dart';
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
  HistoryFilter build() => const HistoryFilter();

  /// Adds/removes [p] from the multi-select period set (union semantics).
  void togglePeriod(TimePeriod p) {
    final s = {...state.periods};
    if (!s.remove(p)) s.add(p);
    state = state.copyWith(periods: s);
  }

  /// The "All" period chip: clears the selection (= no time restriction).
  void clearPeriods() => state = state.copyWith(periods: const {});

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
  void setYear(int? year) => state =
      year == null ? state.copyWith(clearYear: true) : state.copyWith(year: year);

  void reset() => state = const HistoryFilter();
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
  final calc = ref.watch(distanceCalculatorProvider);
  final locale = ref.watch(dateFormatLocaleProvider);
  final repo = ref.watch(rideRepositoryProvider);
  final (start, end) = effectiveRange(filter);
  return repo.getRidesWithTrackpointsInRange(startMs: start, endMs: end).map(
      (rides) => buildHistoryItems(rides, filter, calc: calc, locale: locale));
});

/// Distinct calendar years present in the ride history, descending (newest
/// first) — feeds the filter sheet's year picker. Derived in Dart from the
/// full ride list (small, rarely-changing) rather than a new SQL query.
final availableHistoryYearsProvider = StreamProvider<List<int>>((ref) {
  final repo = ref.watch(rideRepositoryProvider);
  return repo.getAllRidesWithTrackpoints().map((rides) {
    final years = <int>{
      for (final rwt in rides)
        DateTime.fromMillisecondsSinceEpoch(
                rwt.ride.date ?? rwt.ride.startTime ?? 0)
            .year,
    };
    return years.toList()..sort((a, b) => b.compareTo(a));
  });
});

final historyControllerProvider = Provider<HistoryController>(
  (ref) => HistoryController(
    ref.watch(rideRepositoryProvider),
    ref.watch(routePreviewCacheProvider),
  ),
);
