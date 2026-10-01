import 'distance_calculator.dart';
import 'follow_join.dart' show sameRoad;
import 'heading.dart' show LatLng;
import 'route_progress.dart';

/// Which way the rider follows the reference route.
enum FollowDirection { undecided, forward, reverse }

/// Distance a rider must move along the route before the direction is decided.
const double followDirectionDecisionM = 35;

/// Direction decided at the join: forward in the start zone, reverse in the
/// finish zone, undecided elsewhere and always on a loop. On a short open
/// route whose start and finish zones overlap, the start zone (forward) wins.
/// A zone the route also passes mid-route, outside both zones (a "6" whose
/// finish lies on its own middle), leaves it undecided.
FollowDirection directionAtJoin(
  RouteTrack track,
  LatLng position, {
  DistanceCalculator distance = const HaversineDistanceCalculator(),
}) {
  if (track.points.length < 2 || track.lengthM <= 0 || track.isLoop) {
    return FollowDirection.undecided;
  }
  final zone = _endZoneAt(track, position, distance);
  if (zone == FollowDirection.undecided || _passesMidRoute(track, position)) {
    return FollowDirection.undecided;
  }
  return zone;
}

/// Forward within [followFinishRadiusM] of the start, reverse within it of
/// the finish (start first), else undecided.
FollowDirection _endZoneAt(
  RouteTrack track,
  LatLng position,
  DistanceCalculator distance,
) {
  bool near(LatLng p) =>
      distance.distanceBetween(position.lat, position.lng, p.lat, p.lng) <=
      followFinishRadiusM;
  if (near(track.points.first)) return FollowDirection.forward;
  if (near(track.points.last)) return FollowDirection.reverse;
  return FollowDirection.undecided;
}

/// Whether the road at [position] is also ridden outside both end zones.
bool _passesMidRoute(RouteTrack track, LatLng position) =>
    sameRoad(track, track.passesOf(position)).any(
      (h) =>
          h.alongM > followFinishRadiusM &&
          h.alongM < track.lengthM - followFinishRadiusM,
    );

/// Forward once a signed displacement along the route since the join
/// reaches [followDirectionDecisionM] ahead, reverse once one reaches it
/// behind, else undecided. Where the route runs both ways along one road
/// (an out-and-back, a lollipop's stem) the rider is ahead on one pass and
/// behind on the other: forward is the default.
FollowDirection decideDirection(Iterable<double> signedM) {
  if (signedM.any((m) => m >= followDirectionDecisionM)) {
    return FollowDirection.forward;
  }
  if (signedM.any((m) => m <= -followDirectionDecisionM)) {
    return FollowDirection.reverse;
  }
  return FollowDirection.undecided;
}

/// The ridden stretch of the original route, in original-route metres.
class RiddenRange {
  const RiddenRange(this.loM, this.hiM);
  const RiddenRange.at(double m) : loM = m, hiM = m;

  final double loM, hiM;

  RiddenRange extend(double m) =>
      RiddenRange(m < loM ? m : loM, m > hiM ? m : hiM);
}
