import 'distance_calculator.dart';
import 'heading.dart' show LatLng;
import 'route_progress.dart';

/// Which way the rider follows the reference route.
enum FollowDirection { undecided, forward, reverse }

/// Distance a rider must move along the route before the direction is decided.
const double followDirectionDecisionM = 25;

/// Direction decided at the join: forward in the start zone, reverse in the
/// finish zone, undecided elsewhere and always on a loop. On a short open
/// route whose start and finish zones overlap, the start zone (forward) wins.
FollowDirection directionAtJoin(
  RouteTrack track,
  LatLng position, {
  DistanceCalculator distance = const HaversineDistanceCalculator(),
}) {
  if (track.points.length < 2 || track.lengthM <= 0) {
    return FollowDirection.undecided;
  }
  double distanceTo(LatLng p) =>
      distance.distanceBetween(position.lat, position.lng, p.lat, p.lng);
  final first = track.points.first, last = track.points.last;
  final isLoop =
      distance.distanceBetween(first.lat, first.lng, last.lat, last.lng) <=
      followFinishRadiusM;
  if (isLoop) return FollowDirection.undecided;
  if (distanceTo(first) <= followFinishRadiusM) return FollowDirection.forward;
  if (distanceTo(last) <= followFinishRadiusM) return FollowDirection.reverse;
  return FollowDirection.undecided;
}

/// Forward/reverse once either advance reaches [followDirectionDecisionM]
/// (forward wins when both reach it in the same fix), else undecided.
FollowDirection decideDirection({
  required double forwardAdvanceM,
  required double reverseAdvanceM,
}) {
  if (forwardAdvanceM >= followDirectionDecisionM) {
    return FollowDirection.forward;
  }
  if (reverseAdvanceM >= followDirectionDecisionM) {
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
