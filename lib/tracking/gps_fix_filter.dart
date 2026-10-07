import 'dart:math' as math;

import '../domain/distance_calculator.dart';
import 'location_fix.dart';

/// What the recording filter decided about one fix: whether it becomes a
/// trackpoint, how much distance the segment adds (0 for the first point,
/// which has no predecessor to measure against), and the fix still waiting
/// for confirmation after a long stop (see [GpsFixFilter.confirmS]).
typedef FixDecision = ({
  bool record,
  double distanceMetres,
  LocationFix? candidate,
});

/// The GPS recording filter, ported 1:1 from the original Kotlin `RideTracker`
/// including its constants.
///
/// Pure and stateless: it never mutates anything and touches no repository, so
/// every stage is testable on its own. [RideTracker] owns the state (the last
/// recorded fix, the pending candidate, the running distance) and applies
/// these decisions — keeping
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

  /// Stage 4 judges the implied speed over at most this many seconds. Measured
  /// over the full time since the last recorded point, a long stop or an
  /// indoor stretch would hold recording frozen for minutes after the rider
  /// moves on (#70). Beyond this window a fix is only a candidate until
  /// confirmed (stage 5).
  static const double speedWindowS = 60;

  /// Stage 5 — after a long stop, a candidate is confirmed by a fix at least
  /// this many seconds later that is further from the last recorded point by
  /// [minSpeedMs] × the time between them, and by more than the accuracy of
  /// either reading. GPS drift and Wi-Fi jumps around someone standing still
  /// also reach 30 m now and then, but they swing back instead of moving on —
  /// so a stop of hours adds no more noise than one of minutes.
  static const double confirmS = 10;

  /// ~180 km/h — above this the segment is a GPS jump, not a ride.
  static const double maxSpeedMs = 50.0;

  /// Stage 0 — freshness. Applies before any state update: a stale cached fix
  /// must not even move the live marker.
  static bool isFresh(LocationFix fix, int nowNanos) =>
      nowNanos - fix.elapsedRealtimeNanos <= maxFixAgeNanos;

  /// Stages 1–5, run once a ride is active and unpaused.
  ///
  /// [last] is the previously recorded fix, or null when [fix] would be the
  /// ride's first point — that first point is recorded immediately, even at
  /// rest. The stationary/displacement/speed guards below only make sense
  /// against a predecessor; applying them to the first fix would drop the
  /// start of a ride begun standing still, leaving a no-movement ride with
  /// zero points ("No route").
  ///
  /// [candidate] is the previous decision's candidate; pass it back in.
  static FixDecision evaluate({
    required LocationFix fix,
    required LocationFix? last,
    LocationFix? candidate,
    required DistanceCalculator calc,
  }) {
    // 1. Discard low-accuracy fixes. Says nothing about motion, so a pending
    //    candidate stays.
    if (fix.accuracy > accuracyThresholdM) {
      return (record: false, distanceMetres: 0.0, candidate: candidate);
    }

    if (last == null) {
      return (record: true, distanceMetres: 0.0, candidate: null);
    }

    const skip = (record: false, distanceMetres: 0.0, candidate: null);
    final distance = _movedFrom(last, fix, calc);
    if (distance == null) return skip;

    final elapsedS = _secondsBetween(last, fix);
    if (elapsedS <= speedWindowS) {
      return (record: true, distanceMetres: distance, candidate: null);
    }

    // 5. Long stop: confirm by moving on, not by one far-off fix.
    if (candidate == null) {
      return (record: false, distanceMetres: 0.0, candidate: fix);
    }
    final sinceCandidateS = _secondsBetween(candidate, fix);
    if (sinceCandidateS < confirmS) {
      return (record: false, distanceMetres: 0.0, candidate: candidate);
    }
    final candidateDistance = calc.distanceBetween(
      last.latitude,
      last.longitude,
      candidate.latitude,
      candidate.longitude,
    );
    final requiredGrowth = math.max(
      minSpeedMs * sinceCandidateS,
      math.max(candidate.accuracy, fix.accuracy),
    );
    if (distance - candidateDistance < requiredGrowth) {
      return (record: false, distanceMetres: 0.0, candidate: fix);
    }
    return (record: true, distanceMetres: distance, candidate: null);
  }

  /// Stages 1b–4: the distance from [last] to [fix] when it is real movement,
  /// null when it is standing still, drift or a jump.
  static double? _movedFrom(
    LocationFix last,
    LocationFix fix,
    DistanceCalculator calc,
  ) {
    // 1b. Stationary guard: trustworthy near-zero provider speed → skip.
    if (fix.hasSpeed && fix.speed < stationarySpeedMs) return null;

    final distance = calc.distanceBetween(
      last.latitude,
      last.longitude,
      fix.latitude,
      fix.longitude,
    );
    final elapsedS = _secondsBetween(last, fix);

    // 2. Outlier guard: physically impossible implied speed → drop, keep last.
    if (elapsedS > 0.0 && distance / elapsedS > maxSpeedMs) return null;

    // 3. Displacement must exceed the accuracy margin of both readings.
    final requiredDisplacement = math.max(
      minDistanceM,
      math.max(last.accuracy, fix.accuracy),
    );
    if (distance < requiredDisplacement) return null;

    // 4. Implied speed must indicate real movement (catches slow drift). The
    //    time is capped so a long stop doesn't freeze recording afterwards.
    if (elapsedS > 0.0 &&
        distance / math.min(elapsedS, speedWindowS) < minSpeedMs) {
      return null;
    }
    return distance;
  }

  static double _secondsBetween(LocationFix from, LocationFix to) =>
      (to.elapsedRealtimeNanos - from.elapsedRealtimeNanos) / 1000000000.0;
}
