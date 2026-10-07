import 'dart:math' as math;

import '../domain/distance_calculator.dart';
import 'location_fix.dart';

/// A fix to record and the distance its segment adds (0 for the first point,
/// which has no predecessor to measure against).
typedef RecordedFix = ({LocationFix fix, double distanceMetres});

/// What the recording filter decided about one fix: the fixes to record, in
/// order (usually none or this one; after a long stop also the fixes held for
/// confirmation), and the fixes still held (see [GpsFixFilter.confirmS]).
typedef FixDecision = ({List<RecordedFix> recorded, List<LocationFix> pending});

/// The GPS recording filter, ported from the original Kotlin `RideTracker`
/// including its constants; stage 4's time cap and stage 5 deliberately
/// deviate from it (#70).
///
/// Pure and stateless: it never mutates anything and touches no repository, so
/// every stage is testable on its own. [RideTracker] owns the state (the last
/// recorded fix, the held fixes, the running distance) and applies these
/// decisions — keeping the filter maths out of the orchestration it used to be
/// interleaved with.
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
  /// moves on (#70). Beyond this window a fix is held until confirmed
  /// (stage 5).
  static const double speedWindowS = 60;

  /// Stage 5 — after a long stop, fixes are held until a fix at least this
  /// many seconds after a held one is further from the last recorded point by
  /// [minSpeedMs] × the time between them, and by more than the accuracy of
  /// either reading; two fixes in a row with a valid provider speed of at
  /// least [stationarySpeedMs] confirm at once (one alone may be a spike). GPS drift and Wi-Fi jumps around someone standing still
  /// also reach 30 m now and then, but they swing back instead of moving on —
  /// so a stop of hours adds no more noise than one of minutes. Once
  /// confirmed, the held fixes are recorded too, so the route follows the
  /// path taken instead of cutting straight across.
  static const double confirmS = 10;

  /// Held fixes older than this are dropped: whatever they were, it wasn't
  /// the start of a ride that would have been confirmed by now.
  static const double maxHoldS = 120;

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
  /// [pending] is the previous decision's held fixes; pass them back in.
  static FixDecision evaluate({
    required LocationFix fix,
    required LocationFix? last,
    List<LocationFix> pending = const [],
    required DistanceCalculator calc,
  }) {
    // 1. Discard low-accuracy fixes. Says nothing about motion, so held fixes
    //    stay as they are.
    if (fix.accuracy > accuracyThresholdM) {
      return (recorded: const [], pending: pending);
    }

    if (last == null) {
      return (recorded: [(fix: fix, distanceMetres: 0.0)], pending: const []);
    }

    const none = (recorded: <RecordedFix>[], pending: <LocationFix>[]);
    final distance = _movedFrom(last, fix, calc);
    if (distance == null) return none;
    if (_secondsBetween(last, fix) <= speedWindowS) {
      return (
        recorded: [(fix: fix, distanceMetres: distance)],
        pending: const [],
      );
    }

    // 5. Long stop: hold until confirmed by moving on. The newest held fix
    //    stays whatever its age, or fixes minutes apart could never confirm.
    final held = [
      for (final p in pending)
        if (_secondsBetween(p, fix) <= maxHoldS || identical(p, pending.last))
          p,
    ];
    final rollingOn =
        _isRolling(fix) && held.isNotEmpty && _isRolling(held.last);
    if (rollingOn || _confirms(last, held, fix, distance, calc)) {
      return (recorded: _replay(last, [...held, fix], calc), pending: const []);
    }
    return (recorded: const [], pending: [...held, fix]);
  }

  /// Whether [fix] is further from [last] than the oldest held fix at least
  /// [confirmS] earlier, by [minSpeedMs] × the time between them and by more
  /// than the accuracy of either reading. The oldest, so slow progress at poor
  /// accuracy adds up over the hold instead of being judged 10 s at a time.
  static bool _confirms(
    LocationFix last,
    List<LocationFix> held,
    LocationFix fix,
    double distance,
    DistanceCalculator calc,
  ) {
    final reference = held
        .where((p) => _secondsBetween(p, fix) >= confirmS)
        .firstOrNull;
    if (reference == null) return false;
    final growth =
        distance -
        calc.distanceBetween(
          last.latitude,
          last.longitude,
          reference.latitude,
          reference.longitude,
        );
    final required = math.max(
      minSpeedMs * _secondsBetween(reference, fix),
      math.max(reference.accuracy, fix.accuracy),
    );
    return growth >= required;
  }

  /// Runs [fixes] through stages 1b–4 in order, starting from [last], and
  /// returns the ones that pass — a held fix too close to its predecessor is
  /// left out, just as it would have been while riding.
  static List<RecordedFix> _replay(
    LocationFix last,
    List<LocationFix> fixes,
    DistanceCalculator calc,
  ) {
    final recorded = <RecordedFix>[];
    var previous = last;
    for (final f in fixes) {
      final distance = _movedFrom(previous, f, calc);
      if (distance == null) continue;
      recorded.add((fix: f, distanceMetres: distance));
      previous = f;
    }
    return recorded;
  }

  /// A valid provider speed that says the rider is moving.
  static bool _isRolling(LocationFix fix) =>
      fix.hasSpeed && fix.speed >= stationarySpeedMs;

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
    //    time is capped so a long stop doesn't freeze recording afterwards;
    //    beyond the cap, a valid provider speed already shows movement.
    if (elapsedS > speedWindowS && _isRolling(fix)) return distance;
    if (elapsedS > 0.0 &&
        distance / math.min(elapsedS, speedWindowS) < minSpeedMs) {
      return null;
    }
    return distance;
  }

  static double _secondsBetween(LocationFix from, LocationFix to) =>
      (to.elapsedRealtimeNanos - from.elapsedRealtimeNanos) / 1000000000.0;
}
