import 'package:meta/meta.dart';

/// Share of the reference route, from 0 to 1, that a follow must cover to
/// count as complete and compete for the best time (Spec 20). Inclusive.
const double fullCoverageThreshold = 0.9;

/// One ride of a route group (Spec 20): the original or a ride recorded
/// while following it.
@immutable
class RouteGroupRide {
  const RouteGroupRide({
    required this.rideId,
    required this.timestampMs,
    required this.durationMs,
    this.coverage,
  });

  final int rideId;

  /// Start of the ride, epoch milliseconds; orders the follows oldest first.
  final int timestampMs;

  /// Ride time in milliseconds; only a positive one competes for the best.
  final int durationMs;

  /// Share of the reference route the ride covered, as `followCoverage`
  /// gives it. Null = unknown, which counts as partial. Unused on the
  /// original.
  final double? coverage;
}

/// An original ride and the rides that followed it, split for the
/// comparison sheet (Spec 20).
@immutable
class RouteGroup {
  const RouteGroup({
    required this.original,
    required this.complete,
    required this.partial,
    this.bestRideId,
  });

  final RouteGroupRide original;

  /// Follows covering at least [fullCoverageThreshold], oldest first.
  final List<RouteGroupRide> complete;

  /// Follows below [fullCoverageThreshold] or of unknown coverage, oldest
  /// first.
  final List<RouteGroupRide> partial;

  /// The fastest of the original and the complete follows with a positive
  /// duration; a tie keeps the older ride. Null unless at least two compete.
  final int? bestRideId;
}

/// Groups [original] with its [follows] (Spec 20): splits them into complete
/// and partial by coverage and picks the best time.
RouteGroup buildRouteGroup(
  RouteGroupRide original,
  List<RouteGroupRide> follows,
) {
  final byDate = [...follows]
    ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
  final complete = [...byDate.where(_isComplete)];
  return RouteGroup(
    original: original,
    complete: complete,
    partial: [...byDate.where((ride) => !_isComplete(ride))],
    bestRideId: _fastestRideId([original, ...complete]),
  );
}

bool _isComplete(RouteGroupRide ride) =>
    (ride.coverage ?? 0) >= fullCoverageThreshold;

/// Id of the fastest timed ride in [rides], the earlier one on a tie; null
/// unless at least two have a positive duration.
int? _fastestRideId(List<RouteGroupRide> rides) {
  final timed = [...rides.where((ride) => ride.durationMs > 0)];
  if (timed.length < 2) return null;
  return timed
      .reduce((best, ride) => ride.durationMs < best.durationMs ? ride : best)
      .rideId;
}
