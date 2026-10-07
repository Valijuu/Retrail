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
      expect(d.recorded.single.distanceMetres, 0.0);
    });

    test('still drops a low-accuracy first point', () {
      final d = GpsFixFilter.evaluate(
        fix: _fix(accuracy: GpsFixFilter.accuracyThresholdM + 1),
        last: null,
        calc: const _FixedCalc(0),
      );
      expect(d.recorded, isEmpty);
    });
  });

  group('evaluate — subsequent points', () {
    test('records a real segment and reports its distance', () {
      final d = evaluateSegment(20); // 20 m in 1 s → 20 m/s, plausible
      expect(d.recorded.single.distanceMetres, 20.0);
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
      expect(d.recorded, isEmpty);
    });

    test('skips a physically impossible jump (stage 2)', () {
      final d = evaluateSegment(GpsFixFilter.maxSpeedMs + 1); // per second
      expect(d.recorded, isEmpty);
    });

    test('skips a segment below the minimum displacement (stage 3)', () {
      final d = evaluateSegment(GpsFixFilter.minDistanceM - 0.1);
      expect(d.recorded, isEmpty);
    });

    test('requires more displacement when the readings are less accurate', () {
      // The threshold is max(minDistance, worst accuracy of the two readings),
      // so a 20 m move is fine normally but not between two ±25 m fixes.
      expect(evaluateSegment(20).recorded, isNotEmpty);
      expect(evaluateSegment(20, lastAccuracy: 25).recorded, isEmpty);
    });

    test('skips slow drift that clears the displacement floor (stage 4)', () {
      // 9 m in 100 s: far enough, but 0.09 m/s is drift, not riding.
      final d = GpsFixFilter.evaluate(
        fix: _fix(nanos: 100000000000),
        last: _fix(),
        calc: const _FixedCalc(9),
      );
      expect(d.recorded, isEmpty);
    });

    test('judges stage 4 over at most 60 s: 40 m after a 15 min stop clears '
        'it (0.67 m/s) and is held for confirmation', () {
      // Over the full 900 s that's 0.04 m/s — the freeze after a stop (#70).
      final d = GpsFixFilter.evaluate(
        fix: _fix(nanos: 900 * 1000000000),
        last: _fix(),
        calc: const _FixedCalc(40),
      );
      expect(d.recorded, isEmpty);
      expect(d.pending, hasLength(1));
    });

    test('still skips drift after a long stop: 25 m after 15 min → 0.42 m/s '
        'over the capped 60 s', () {
      final d = GpsFixFilter.evaluate(
        fix: _fix(nanos: 900 * 1000000000),
        last: _fix(),
        calc: const _FixedCalc(25),
      );
      expect(d.recorded, isEmpty);
    });

    test('skips a low-accuracy fix before anything else (stage 1)', () {
      final d = evaluateSegment(
        20,
        fix: _fix(
          accuracy: GpsFixFilter.accuracyThresholdM + 1,
          nanos: 1000000000,
        ),
      );
      expect(d.recorded, isEmpty);
    });
  });

  // More than a minute after the last recorded point, a fix that clears
  // stages 1–4 is held, not recorded: GPS drift and Wi-Fi jumps around someone
  // standing still reach 30 m too, but they don't keep moving away (#70). Once
  // movement is confirmed, the held fixes are recorded in order, so the route
  // follows the path actually taken instead of cutting straight across.
  group('evaluate — confirmation after a long stop', () {
    // Last recorded at 0 m, then 15 minutes without a recorded point.
    final last = _at(0, 0);

    FixDecision evaluate(
      LocationFix fix, [
      List<LocationFix> pending = const [],
    ]) => GpsFixFilter.evaluate(
      fix: fix,
      last: last,
      pending: pending,
      calc: const _LineCalc(),
    );

    List<double> metresOf(FixDecision d) => [
      for (final r in d.recorded) r.fix.latitude,
    ];

    test('holds a far-off fix without provider speed', () {
      final fix = _at(40, 900);
      final d = evaluate(fix);
      expect(d.recorded, isEmpty);
      expect(d.pending, [fix]);
    });

    test(
      'keeps holding while less than 10 s have passed: 40 m → 45 m in 5 s',
      () {
        final d = evaluate(_at(45, 905), [_at(40, 900)]);
        expect(d.recorded, isEmpty);
        expect([for (final f in d.pending) f.latitude], [40, 45]);
      },
    );

    test('confirms once a fix 10 s after a held one is further away by '
        '0.5 m/s and the accuracy: 40 → 50 → 60 m records all three', () {
      final d = evaluate(_at(60, 910), [_at(40, 900), _at(50, 905)]);
      expect(metresOf(d), [40, 50, 60]);
      expect([for (final r in d.recorded) r.distanceMetres], [40, 10, 10]);
      expect(d.pending, isEmpty);
    });

    test('a held fix too close to the previous one is left out of the replay: '
        '40 → 44 → 52 m records 40 and 52', () {
      final d = evaluate(_at(52, 910), [_at(40, 900), _at(44, 905)]);
      expect(metresOf(d), [40, 52]);
      expect([for (final r in d.recorded) r.distanceMetres], [40, 12]);
    });

    test('a fix that holds its distance is not confirmed but held too: '
        '40 m → 44 m in 10 s', () {
      final d = evaluate(_at(44, 910), [_at(40, 900)]);
      expect(d.recorded, isEmpty);
      expect([for (final f in d.pending) f.latitude], [40, 44]);
    });

    test('moving on by less than the accuracy is not confirmed: 40 m → 52 m '
        'in 10 s at ±15 m', () {
      final d = evaluate(_at(52, 910, accuracy: 15), [
        _at(40, 900, accuracy: 15),
      ]);
      expect(d.recorded, isEmpty);
    });

    test('a jump back towards the last point drops the held fixes', () {
      final d = evaluate(_at(3, 910), [_at(40, 900)]);
      expect(d.recorded, isEmpty);
      expect(d.pending, isEmpty);
    });

    test('a provider speed of 0 drops the held fixes (standing still)', () {
      final d = evaluate(_at(47, 910, hasSpeed: true, speed: 0), [
        _at(40, 900),
      ]);
      expect(d.recorded, isEmpty);
      expect(d.pending, isEmpty);
    });

    test('a fix too vague to judge keeps the held fixes as they are', () {
      final pending = [_at(40, 900)];
      final d = evaluate(
        _at(47, 910, accuracy: GpsFixFilter.accuracyThresholdM + 1),
        pending,
      );
      expect(d.recorded, isEmpty);
      expect(d.pending, pending);
    });

    test('held fixes older than 2 minutes are dropped', () {
      final d = evaluate(_at(45, 1030), [_at(40, 900), _at(44, 1025)]);
      expect([for (final f in d.pending) f.latitude], [44, 45]);
    });

    // Rolling on, the GPS reports a real speed — that alone confirms, so
    // recording follows a skater from the first metres instead of 10 s later.
    group('with a valid provider speed', () {
      test('records at once, 12 m from the stop point', () {
        final d = evaluate(_at(12, 900, hasSpeed: true, speed: 4));
        expect(metresOf(d), [12]);
        expect(d.pending, isEmpty);
      });

      test('confirms and replays the held fixes', () {
        final d = evaluate(_at(47, 902, hasSpeed: true, speed: 4), [
          _at(35, 899),
          _at(40, 900),
        ]);
        expect(metresOf(d), [35, 47]);
      });

      test('still needs the displacement floor: 6 m is not recorded', () {
        final d = evaluate(_at(6, 900, hasSpeed: true, speed: 4));
        expect(d.recorded, isEmpty);
      });

      test('below 0.8 m/s it is standing still, as everywhere', () {
        final d = evaluate(_at(40, 900, hasSpeed: true, speed: 0.5));
        expect(d.recorded, isEmpty);
        expect(d.pending, isEmpty);
      });
    });

    test('within a minute of the last point nothing is held: 40 m in 60 s is '
        'recorded at once', () {
      final d = evaluate(_at(40, 60));
      expect(metresOf(d), [40]);
      expect(d.pending, isEmpty);
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
