import 'dart:math' as math;

import '../domain/distance_calculator.dart';
import 'location_fix.dart';

/// What the recording filter decided about one fix: whether it becomes a
/// trackpoint, and how much distance the segment adds (0 for the first point,
/// which has no predecessor to measure against).
typedef FixDecision = ({bool record, double distanceMetres});

/// The GPS recording filter, ported 1:1 from the original Kotlin `RideTracker`
/// including its constants.
///
/// Pure and stateless: it never mutates anything and touches no repository, so
/// every stage is testable on its own. [RideTracker] owns the state (the last
/// recorded fix, the running distance) and applies these decisions — keeping
/// the filter maths out of the orchestration it used to be interleaved with.
abstract final class GpsFixFilter {
  /// Fixes older than this are cached leftovers, not the rider's position.
  static const int maxFixAgeNanos = 5000000000; // 5 s

  /// Above this accuracy radius a fix is too vague to record.
  static const double accuracyThresholdM = 35;

  /// A segment must clear at least this much ground (and the accuracy margin
  /// of both readings — see [evaluate]) to count as movement.
  static const double minDistanceM = 8.0;

  /// Below this implied speed a segment is GPS drift, not riding.
  static const double minSpeedMs = 0.5;

  /// A trustworthy provider speed below this means the rider is standing still.
  static const double stationarySpeedMs = 0.8;

  /// ~180 km/h — above this the segment is a GPS jump, not a ride.
  static const double maxSpeedMs = 50.0;

  /// Stage 0 — freshness. Applies before any state update: a stale cached fix
  /// must not even move the live marker.
  static bool isFresh(LocationFix fix, int nowNanos) =>
      nowNanos - fix.elapsedRealtimeNanos <= maxFixAgeNanos;

  /// Stages 1–4, run once a ride is active and unpaused.
  ///
  /// [last] is the previously recorded fix, or null when [fix] would be the
  /// ride's first point — that first point is recorded immediately, even at
  /// rest. The stationary/displacement/speed guards below only make sense
  /// against a predecessor; applying them to the first fix would drop the
  /// start of a ride begun standing still, leaving a no-movement ride with
  /// zero points ("No route").
  static FixDecision evaluate({
    required LocationFix fix,
    required LocationFix? last,
    required DistanceCalculator calc,
  }) {
    const skip = (record: false, distanceMetres: 0.0);

    // 1. Discard low-accuracy fixes.
    if (fix.accuracy > accuracyThresholdM) return skip;

    if (last == null) return (record: true, distanceMetres: 0.0);

    // 1b. Stationary guard: trustworthy near-zero provider speed → skip.
    if (fix.hasSpeed && fix.speed < stationarySpeedMs) return skip;

    final distance = calc.distanceBetween(
        last.latitude, last.longitude, fix.latitude, fix.longitude);
    final elapsedS =
        (fix.elapsedRealtimeNanos - last.elapsedRealtimeNanos) / 1000000000.0;

    // 2. Outlier guard: physically impossible implied speed → drop, keep last.
    if (elapsedS > 0.0 && distance / elapsedS > maxSpeedMs) return skip;

    // 3. Displacement must exceed the accuracy margin of both readings.
    final requiredDisplacement =
        math.max(minDistanceM, math.max(last.accuracy, fix.accuracy));
    if (distance < requiredDisplacement) return skip;

    // 4. Implied speed must indicate real movement (catches slow drift).
    if (elapsedS > 0.0 && distance / elapsedS < minSpeedMs) return skip;

    return (record: true, distanceMetres: distance);
  }
}
