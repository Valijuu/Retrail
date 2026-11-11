import '../../data/db/app_database.dart' show Ride;
import '../../domain/ride_stats.dart';
import '../../domain/route_group.dart';
import '../history/history_items.dart';
import '../history/route_group_providers.dart' show routeGroupRideOf;

/// Which rides hold the best time of their route group, and how big each
/// ride's group is (#96). The time comes from @RouteGroup, never recomputed.
class RouteBadges {
  const RouteBadges(
    this.bestRideIds,
    this._groupSizeByRide, [
    this._groupKeyByRide = const {},
  ]);

  final Set<int> bestRideIds;
  final Map<int, int> _groupSizeByRide;
  final Map<int, int> _groupKeyByRide;

  /// One key for every ride of a route group (the original's id), the ride's
  /// own id outside any group.
  int groupKeyOf(int rideId) => _groupKeyByRide[rideId] ?? rideId;

  /// Rides in the route group of [rideId], itself included; `1` outside any.
  int groupSizeOf(int rideId) => _groupSizeByRide[rideId] ?? 1;
}

/// The badges for [rides]: every original with at least one follow forms a
/// group; a follow whose original is gone stands alone.
RouteBadges routeBadges(List<Ride> rides) {
  final byId = {for (final r in rides) r.rideId: r};
  final followsByRoot = <int, List<Ride>>{};
  for (final ride in rides) {
    final root = ride.followedRideId;
    if (root != null && byId.containsKey(root)) {
      (followsByRoot[root] ??= []).add(ride);
    }
  }
  final best = <int>{};
  final sizes = <int, int>{};
  final keys = <int, int>{};
  RouteGroupRide competitor(Ride r) => routeGroupRideOf(
    RideEntryItem(r, storedRideStats(r) ?? statsWithoutTrackpoints(r)),
  );
  for (final MapEntry(key: rootId, value: follows) in followsByRoot.entries) {
    final group = buildRouteGroup(competitor(byId[rootId]!), [
      for (final f in follows) competitor(f),
    ]);
    final bestId = group.bestRideId;
    if (bestId != null) best.add(bestId);
    sizes[rootId] = follows.length + 1;
    keys[rootId] = rootId;
    for (final f in follows) {
      sizes[f.rideId] = follows.length + 1;
      keys[f.rideId] = rootId;
    }
  }
  return RouteBadges(best, sizes, keys);
}
