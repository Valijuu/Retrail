import 'distance_calculator.dart';
import 'heading.dart' show LatLng;
import 'route_progress.dart';

/// Which way the rider follows the reference route.
enum FollowDirection { undecided, forward, reverse }

/// Distance a rider must move along the route before the direction is decided.
const double followDirectionDecisionM = 25;

/// Direction decided at the join: forward in the start zone, reverse in the
/// finish zone, undecided elsewhere and always on a loop.
FollowDirection directionAtJoin(
  RouteTrack track,
  LatLng position, {
  DistanceCalculator distance = const HaversineDistanceCalculator(),
}) {
  if (track.points.length < 2 || track.lengthM <= 0) {
    return FollowDirection.undecided;
  }
  double to(LatLng p) =>
      distance.distanceBetween(position.lat, position.lng, p.lat, p.lng);
  final first = track.points.first, last = track.points.last;
  final isLoop =
      distance.distanceBetween(first.lat, first.lng, last.lat, last.lng) <=
      followFinishRadiusM;
  if (isLoop) return FollowDirection.undecided;
  if (to(first) <= followFinishRadiusM) return FollowDirection.forward;
  if (to(last) <= followFinishRadiusM) return FollowDirection.reverse;
  return FollowDirection.undecided;
}

/// Forward/reverse once either advance reaches [followDirectionDecisionM]
/// (forward wins a tie), else undecided.
FollowDirection decideDirection({
  required double forwardAdvanceM,
  required double reverseAdvanceM,
}) {
  final forward = forwardAdvanceM >= followDirectionDecisionM;
  final reverse = reverseAdvanceM >= followDirectionDecisionM;
  if (forward && reverse) {
    return forwardAdvanceM >= reverseAdvanceM
        ? FollowDirection.forward
        : FollowDirection.reverse;
  }
  if (forward) return FollowDirection.forward;
  if (reverse) return FollowDirection.reverse;
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
