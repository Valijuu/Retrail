import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/ride_with_trackpoints.dart';
import '../../data/repositories/data_providers.dart';
import '../../domain/activity_type.dart';
import '../../domain/distance_calculator.dart';
import '../../domain/stats_aggregation.dart';
import '../../domain/time_bounds.dart';
import '../../tracking/tracking_providers.dart';
import '../settings/settings_providers.dart';
import 'recent_ride_ui.dart';

/// "Now" in epoch ms — overridable in tests for deterministic time bounds.
final nowMsProvider =
    Provider<int Function()>((ref) => () => DateTime.now().millisecondsSinceEpoch);

StreamProvider<WeeklyStats> _statsFor(Bounds Function(int) boundsOf) {
  return StreamProvider<WeeklyStats>((ref) {
    final now = ref.watch(nowMsProvider)();
    final bounds = boundsOf(now);
    final calc = ref.watch(distanceCalculatorProvider);
    return ref
        .watch(rideRepositoryProvider)
        .getRidesWithTrackpointsBetween(bounds.$1, bounds.$2)
        .map((rides) => aggregateStats(rides, calc));
  });
}

final weeklyStatsProvider = _statsFor((now) => weekBounds(nowMs: now));
final dailyStatsProvider = _statsFor((now) => dayBounds(nowMs: now));
final yearlyStatsProvider = _statsFor((now) => yearBounds(nowMs: now));

/// Newest 2 FINISHED rides by date → UI models. Rides without an endTime are
/// in progress (the row is inserted at ride start) or mid-discard — neither
/// belongs in "last rides", and showing them made a discarded ride flash on
/// home until its delete landed.
List<RecentRideUi> toRecentRides(
    List<RideWithTrackpoints> list, DistanceCalculator calc,
    {String? locale}) {
  final sorted = list.where((rwt) => rwt.ride.endTime != null).toList()
    ..sort((a, b) => (b.ride.date ?? 0).compareTo(a.ride.date ?? 0));
  return sorted
      .take(2)
      .map((rwt) => RecentRideUi.from(rwt, calc, locale: locale))
      .toList();
}

/// Favorites sorted by when they were hearted (newest first), take 2.
List<RecentRideUi> toFavoriteRides(
    List<RideWithTrackpoints> list, DistanceCalculator calc,
    {String? locale}) {
  final favs = list.where((rwt) => rwt.ride.isFavorite).toList()
    ..sort((a, b) => (b.ride.favoritedAt ?? b.ride.date ?? 0)
        .compareTo(a.ride.favoritedAt ?? a.ride.date ?? 0));
  return favs
      .take(2)
      .map((rwt) => RecentRideUi.from(rwt, calc, locale: locale))
      .toList();
}

final recentRidesProvider = StreamProvider<List<RecentRideUi>>((ref) {
  final calc = ref.watch(distanceCalculatorProvider);
  final locale = ref.watch(dateFormatLocaleProvider);
  return ref
      .watch(rideRepositoryProvider)
      .getAllRidesWithTrackpoints()
      .map((list) => toRecentRides(list, calc, locale: locale));
});

final favoriteRidesProvider = StreamProvider<List<RecentRideUi>>((ref) {
  final calc = ref.watch(distanceCalculatorProvider);
  final locale = ref.watch(dateFormatLocaleProvider);
  return ref
      .watch(rideRepositoryProvider)
      .getAllRidesWithTrackpoints()
      .map((list) => toFavoriteRides(list, calc, locale: locale));
});

final lastActivityTypeProvider = StreamProvider<ActivityType>((ref) => ref
    .watch(preferencesRepositoryProvider)
    .lastActivityType
    .map((id) => ActivityType.fromId(id) ?? ActivityType.defaultType));

final userNameProvider = StreamProvider<String>(
    (ref) => ref.watch(preferencesRepositoryProvider).userName);

/// Records the chosen activity type for the ride about to start.
class HomeController {
  HomeController(this._ref);
  final Ref _ref;

  void beginTracking(ActivityType type) {
    _ref.read(rideTrackerProvider).setPendingActivityType(type.id);
    _ref.read(preferencesRepositoryProvider).saveLastActivityType(type.id);
  }
}

final homeControllerProvider = Provider<HomeController>(HomeController.new);
