import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/distance_calculator.dart';
import 'package:retrail/tracking/gps_fix_filter.dart';
import 'package:retrail/tracking/location_fix.dart';

const _second = 1000000000;

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
}) => LocationFix(
  latitude: 52,
  longitude: 13,
  accuracy: accuracy,
  hasSpeed: hasSpeed,
  speed: speed,
  elapsedRealtimeNanos: nanos,
);

/// Runs the filter against a predecessor one second earlier, so the implied
/// speed is simply `metres` per second.
FixDecision evaluateSegment(
  double metres, {
  LocationFix? fix,
  double lastAccuracy = 5,
}) => GpsFixFilter.evaluate(
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
        GpsFixFilter.isFresh(_fix(), GpsFixFilter.maxFixAgeNanos + 1),
        isFalse,
      );
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
          nanos: 1000000000,
        ),
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

    test('judges stage 4 over at most 60 s: 40 m after a 15 min stop clears '
        'it (0.67 m/s) and becomes a candidate', () {
      // Over the full 900 s that's 0.04 m/s — the freeze after a stop (#70).
      final d = GpsFixFilter.evaluate(
        fix: _fix(nanos: 900 * 1000000000),
        last: _fix(),
        calc: const _FixedCalc(40),
      );
      expect(d.record, isFalse);
      expect(d.candidate, isNotNull);
    });

    test('still skips drift after a long stop: 25 m after 15 min → 0.42 m/s '
        'over the capped 60 s', () {
      final d = GpsFixFilter.evaluate(
        fix: _fix(nanos: 900 * 1000000000),
        last: _fix(),
        calc: const _FixedCalc(25),
      );
      expect(d.record, isFalse);
    });

    test('skips a low-accuracy fix before anything else (stage 1)', () {
      final d = evaluateSegment(
        20,
        fix: _fix(
          accuracy: GpsFixFilter.accuracyThresholdM + 1,
          nanos: 1000000000,
        ),
      );
      expect(d.record, isFalse);
    });
  });

  // After more than a minute without a recorded point, a fix that clears
  // stages 1–4 is only a candidate: GPS drift and Wi-Fi jumps around someone
  // standing still reach 30 m too, but they don't keep moving away (#70).
  group('evaluate — confirmation after a long stop', () {
    // Last recorded at 0 m, then 15 minutes without a recorded point.
    final last = _at(0, 0);

    test('records once a fix ≥ 10 s after the candidate is 7 m further away: '
        '40 m → 47 m in 10 s', () {
      final d = GpsFixFilter.evaluate(
        fix: _at(47, 910),
        last: last,
        candidate: _at(40, 900),
        calc: const _LineCalc(),
      );
      expect(d.record, isTrue);
      expect(d.distanceMetres, 47.0);
      expect(d.candidate, isNull);
    });

    test('keeps the candidate while less than 10 s have passed', () {
      final candidate = _at(40, 900);
      final d = GpsFixFilter.evaluate(
        fix: _at(45, 905),
        last: last,
        candidate: candidate,
        calc: const _LineCalc(),
      );
      expect(d.record, isFalse);
      expect(d.candidate, same(candidate));
    });

    test('a candidate that holds its distance is not confirmed — the newer fix '
        'becomes the candidate: 40 m → 44 m in 10 s', () {
      final fix = _at(44, 910);
      final d = GpsFixFilter.evaluate(
        fix: fix,
        last: last,
        candidate: _at(40, 900),
        calc: const _LineCalc(),
      );
      expect(d.record, isFalse);
      expect(d.candidate, same(fix));
    });

    test('moving on by less than the accuracy is not confirmed: 40 m → 52 m '
        'in 10 s at ±15 m', () {
      final d = GpsFixFilter.evaluate(
        fix: _at(52, 910, accuracy: 15),
        last: last,
        candidate: _at(40, 900, accuracy: 15),
        calc: const _LineCalc(),
      );
      expect(d.record, isFalse);
    });

    test('a jump back towards the last point drops the candidate', () {
      final d = GpsFixFilter.evaluate(
        fix: _at(3, 910),
        last: last,
        candidate: _at(40, 900),
        calc: const _LineCalc(),
      );
      expect(d.record, isFalse);
      expect(d.candidate, isNull);
    });

    test('a provider speed of 0 drops the candidate (standing still)', () {
      final d = GpsFixFilter.evaluate(
        fix: _at(47, 910, hasSpeed: true, speed: 0),
        last: last,
        candidate: _at(40, 900),
        calc: const _LineCalc(),
      );
      expect(d.record, isFalse);
      expect(d.candidate, isNull);
    });

    test('a fix too vague to judge keeps the candidate', () {
      final candidate = _at(40, 900);
      final d = GpsFixFilter.evaluate(
        fix: _at(47, 910, accuracy: GpsFixFilter.accuracyThresholdM + 1),
        last: last,
        candidate: candidate,
        calc: const _LineCalc(),
      );
      expect(d.record, isFalse);
      expect(d.candidate, same(candidate));
    });

    test('within a minute of the last point nothing needs confirming: 40 m in '
        '60 s is recorded at once', () {
      final d = GpsFixFilter.evaluate(
        fix: _at(40, 60),
        last: last,
        calc: const _LineCalc(),
      );
      expect(d.record, isTrue);
      expect(d.candidate, isNull);
    });
  });
}

/// Positions on a straight line: latitude is metres along it, so a segment's
/// length is the latitude difference.
class _LineCalc implements DistanceCalculator {
  const _LineCalc();
  @override
  double distanceBetween(double a, double b, double c, double d) =>
      (c - a).abs();
}

/// A fix [metres] along the line, [seconds] after the ride's first fix.
LocationFix _at(
  double metres,
  int seconds, {
  double accuracy = 5,
  bool hasSpeed = false,
  double speed = 0,
}) => LocationFix(
  latitude: metres,
  longitude: 0,
  accuracy: accuracy,
  hasSpeed: hasSpeed,
  speed: speed,
  elapsedRealtimeNanos: seconds * _second,
);
