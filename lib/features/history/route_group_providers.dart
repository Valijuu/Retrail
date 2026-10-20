import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart' show Ride;
import '../../data/db/followed_route.dart';
import '../../data/repositories/data_providers.dart';
import '../../domain/ride_stats.dart';
import '../../domain/route_group.dart';
import 'history_items.dart';

/// How often each original was followed, by its ride id (Spec 20).
final followCountsProvider = StreamProvider<Map<int, int>>(
  (ref) => ref.watch(rideRepositoryProvider).watchFollowCounts(),
);

/// Every followed original, most recently ridden first — the History route
/// filter's choices (Spec 20).
final followedRoutesProvider = StreamProvider<List<FollowedRoute>>(
  (ref) => ref.watch(rideRepositoryProvider).watchFollowedRoutes(),
);

/// A route group for the comparison sheet: the split and best time, plus each
/// ride with its stats by ride id.
class RouteGroupView {
  const RouteGroupView(this.group, this.entries);
  final RouteGroup group;
  final Map<int, RideEntryItem> entries;
}

/// The route group of the original [rootId]; null once it is gone (Spec 20).
final routeGroupProvider = StreamProvider.autoDispose
    .family<RouteGroupView?, int>(
      (ref, rootId) => ref
          .watch(rideRepositoryProvider)
          .watchRouteGroup(rootId)
          .map((rides) => _view(rootId, rides)),
    );

RouteGroupView? _view(int rootId, List<Ride> rides) {
  if (rides.isEmpty) return null;
  final entries = {
    for (final ride in rides)
      ride.rideId: RideEntryItem(
        ride,
        storedRideStats(ride) ?? statsWithoutTrackpoints(ride),
      ),
  };
  RouteGroupRide groupRide(RideEntryItem e) => RouteGroupRide(
    rideId: e.ride.rideId,
    timestampMs: e.ride.date ?? e.ride.startTime ?? 0,
    // A follow competes with its time on the route (#79); the original's
    // ride is the route.
    durationMs: e.ride.followRouteMs ?? e.stats.durationMs,
    coverage: e.ride.followCoverage,
  );
  final group = buildRouteGroup(groupRide(entries[rootId]!), [
    for (final e in entries.values)
      if (e.ride.rideId != rootId) groupRide(e),
  ]);
  return RouteGroupView(group, entries);
}
