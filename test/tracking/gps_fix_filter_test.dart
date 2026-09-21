import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/distance_calculator.dart';
import 'package:retrail/tracking/gps_fix_filter.dart';
import 'package:retrail/tracking/location_fix.dart';

/// Fixed distance per segment, isolating the filter from real geometry (same
/// approach as the tracker tests, which mock the calculator to a constant).
class _FixedCalc implements DistanceCalculator {
  const _FixedCalc(this.metres);
  final double metres;
  @override
  double distanceBetween(double a, double b, double c, double d) => metres;
}

LocationFix _fix({
  double accuracy = 5,
  bool hasSpeed = false,
  double speed = 0,
  int nanos = 0,
}) =>
    LocationFix(
      latitude: 52,
      longitude: 13,
      accuracy: accuracy,
      hasSpeed: hasSpeed,
      speed: speed,
      elapsedRealtimeNanos: nanos,
    );

/// Runs the filter against a predecessor one second earlier, so the implied
/// speed is simply `metres` per second.
FixDecision evaluateSegment(double metres, {LocationFix? fix, double lastAccuracy = 5}) =>
    GpsFixFilter.evaluate(
      fix: fix ?? _fix(nanos: 1000000000),
      last: _fix(accuracy: lastAccuracy),
      calc: _FixedCalc(metres),
    );

void main() {
  group('isFresh (stage 0)', () {
    test('a fix captured now is fresh', () {
      expect(GpsFixFilter.isFresh(_fix(nanos: 1000000000), 1000000000), isTrue);
    });

    test('a fix exactly at the age limit still counts as fresh', () {
      expect(GpsFixFilter.isFresh(_fix(), GpsFixFilter.maxFixAgeNanos), isTrue);
    });

    test('a fix older than the limit is stale', () {
      expect(
          GpsFixFilter.isFresh(_fix(), GpsFixFilter.maxFixAgeNanos + 1), isFalse);
    });
  });

  group('evaluate — first point', () {
    test('records the first point even at rest, adding no distance', () {
      // A ride begun standing still must still get its start point, or it ends
      // up with zero points and renders as "No route".
      final d = GpsFixFilter.evaluate(
        fix: _fix(hasSpeed: true, speed: 0),
        last: null,
        calc: const _FixedCalc(0),
      );
      expect(d.record, isTrue);
      expect(d.distanceMetres, 0.0);
    });

    test('still drops a low-accuracy first point', () {
      final d = GpsFixFilter.evaluate(
        fix: _fix(accuracy: GpsFixFilter.accuracyThresholdM + 1),
        last: null,
        calc: const _FixedCalc(0),
      );
      expect(d.record, isFalse);
    });
  });

  group('evaluate — subsequent points', () {
    test('records a real segment and reports its distance', () {
      final d = evaluateSegment(20); // 20 m in 1 s → 20 m/s, plausible
      expect(d.record, isTrue);
      expect(d.distanceMetres, 20.0);
    });

    test('skips a trustworthy near-zero provider speed (stage 1b)', () {
      final d = evaluateSegment(
        20,
        fix: _fix(
            hasSpeed: true,
            speed: GpsFixFilter.stationarySpeedMs - 0.1,
            nanos: 1000000000),
      );
      expect(d.record, isFalse);
    });

    test('skips a physically impossible jump (stage 2)', () {
      final d = evaluateSegment(GpsFixFilter.maxSpeedMs + 1); // per second
      expect(d.record, isFalse);
      expect(d.distanceMetres, 0.0);
    });

    test('skips a segment below the minimum displacement (stage 3)', () {
      final d = evaluateSegment(GpsFixFilter.minDistanceM - 0.1);
      expect(d.record, isFalse);
    });

    test('requires more displacement when the readings are less accurate', () {
      // The threshold is max(minDistance, worst accuracy of the two readings),
      // so a 20 m move is fine normally but not between two ±25 m fixes.
      expect(evaluateSegment(20).record, isTrue);
      expect(evaluateSegment(20, lastAccuracy: 25).record, isFalse);
    });

    test('skips slow drift that clears the displacement floor (stage 4)', () {
      // 9 m in 100 s: far enough, but 0.09 m/s is drift, not riding.
      final d = GpsFixFilter.evaluate(
        fix: _fix(nanos: 100000000000),
        last: _fix(),
        calc: const _FixedCalc(9),
      );
      expect(d.record, isFalse);
    });

    test('skips a low-accuracy fix before anything else (stage 1)', () {
      final d = evaluateSegment(
        20,
        fix: _fix(
            accuracy: GpsFixFilter.accuracyThresholdM + 1, nanos: 1000000000),
      );
      expect(d.record, isFalse);
    });
  });
}
