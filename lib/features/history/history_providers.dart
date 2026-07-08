import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/activity_type.dart';
import '../../data/repositories/data_providers.dart';
import '../../tracking/tracking_providers.dart';
import '../active_ride/active_ride_providers.dart';
import 'history_controller.dart';
import 'history_filter.dart';
import 'history_items.dart';

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
  final repo = ref.watch(rideRepositoryProvider);
  return repo
      .getAllRidesWithTrackpoints()
      .map((rides) => buildHistoryItems(rides, filter, calc: calc));
});

final historyControllerProvider = Provider<HistoryController>(
  (ref) => HistoryController(
    ref.watch(rideRepositoryProvider),
    ref.watch(routePreviewCacheProvider),
  ),
);
