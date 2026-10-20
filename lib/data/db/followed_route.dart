import 'app_database.dart';

/// An original ride that was followed at least once (Spec 20), with the size
/// of its route group and when any ride of the group was ridden last — one
/// entry of the History "Followed routes" filter.
class FollowedRoute {
  const FollowedRoute({
    required this.original,
    required this.rideCount,
    required this.lastRiddenMs,
  });

  final Ride original;

  /// The original plus its follows.
  final int rideCount;
  final int lastRiddenMs;
}

/// The route group a ride belongs to (Spec 20).
extension RouteRoot on Ride {
  /// The group's original: the ride this one followed, else the ride itself.
  int get routeRootId => followedRideId ?? rideId;
}
