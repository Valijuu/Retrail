import 'dart:math' as math;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:retrail/data/repositories/ride_repository.dart';
import 'package:retrail/data/repositories/trackpoint_repository.dart';
import 'package:retrail/domain/distance_calculator.dart';
import 'package:retrail/tracking/location_fix.dart';
import 'package:retrail/tracking/ride_tracker.dart';

// Seeded scenarios for stages 4–5 of the recording filter (#70): recording
// must pick up again quickly after a long stop or an indoor stretch, without
// turning GPS noise around someone standing still into distance — however
// long the stop lasts.
//
// Positions are plain metres on a plane (latitude = y, longitude = x), so the
// noise models stay readable; [_PlaneCalc] measures them.

class _MockRideRepo extends Mock implements RideRepository {}

class _MockTpRepo extends Mock implements TrackpointRepository {}

class _PlaneCalc implements DistanceCalculator {
  const _PlaneCalc();
  @override
  double distanceBetween(double y1, double x1, double y2, double x2) =>
      math.sqrt(math.pow(y2 - y1, 2) + math.pow(x2 - x1, 2));
}

const _second = 1000000000;
const _seeds = 20;

/// One received fix: where, when, how accurate, and the provider speed if any.
typedef _Fix = ({double y, double x, int s, double accuracy, double? speed});

/// What a recording made of a fix stream.
typedef _Result = ({
  double distance,
  List<int> recordedAt,
  List<({double lat, double lng})> trackPoints,
});

/// Feeds [fixes] through a recording [RideTracker], one fix per tick of
/// `nowNanos` like a real location stream.
_Result _record(List<_Fix> fixes) {
  final rideRepo = _MockRideRepo();
  final tpRepo = _MockTpRepo();
  when(
    () => rideRepo.startRide(
      activityTypeId: any(named: 'activityTypeId'),
      startedAtMs: any(named: 'startedAtMs'),
    ),
  ).thenAnswer((_) async => 1);
  when(
    () => tpRepo.addTrackpoint(
      rideId: any(named: 'rideId'),
      latitude: any(named: 'latitude'),
      longitude: any(named: 'longitude'),
      timestampMs: any(named: 'timestampMs'),
      speedMs: any(named: 'speedMs'),
    ),
  ).thenAnswer((_) async {});

  late _Result result;
  fakeAsync((fa) {
    final t = RideTracker(rideRepo, tpRepo, const _PlaneCalc());
    t.nowNanos = () => 0;
    t.startTracking();
    fa.flushMicrotasks();
    final recordedAt = <int>[];
    for (final f in fixes) {
      t.nowNanos = () => f.s * _second;
      final before = t.state.trackPoints.length;
      t.onLocationReceived(
        LocationFix(
          latitude: f.y,
          longitude: f.x,
          accuracy: f.accuracy,
          hasSpeed: f.speed != null,
          speed: f.speed ?? 0,
          elapsedRealtimeNanos: f.s * _second,
        ),
      );
      if (t.state.trackPoints.length > before) recordedAt.add(f.s);
    }
    result = (
      distance: t.state.distanceMetres,
      recordedAt: recordedAt,
      trackPoints: t.state.trackPoints,
    );
    t.dispose();
  });
  return result;
}

double _gauss(math.Random r) =>
    math.sqrt(-2 * math.log(1 - r.nextDouble())) *
    math.cos(2 * math.pi * r.nextDouble());

/// White GPS noise with standard deviation [sigma] per axis.
({double y, double x}) Function() _whiteNoise(math.Random r, double sigma) =>
    () => (y: sigma * _gauss(r), x: sigma * _gauss(r));

/// Ornstein–Uhlenbeck drift: the reported position wanders slowly (time
/// constant [tau] seconds) around the true one with spread [sigma] per axis —
/// what a phone at rest actually reports. Advance once per second.
({double y, double x}) Function() _ouDrift(
  math.Random r,
  double sigma,
  double tau,
) {
  final a = math.exp(-1 / tau);
  final step = sigma * math.sqrt(1 - a * a);
  var y = sigma * _gauss(r), x = sigma * _gauss(r);
  return () {
    y = a * y + step * _gauss(r);
    x = a * x + step * _gauss(r);
    return (y: y, x: x);
  };
}

/// Builds a fix stream from a [path] (true position at second `s`), sampled
/// every [every] seconds from 0 to [until], with [noise] added.
List<_Fix> _stream(
  ({double y, double x}) Function(int s) path, {
  required int until,
  int every = 1,
  ({double y, double x}) Function()? noise,
  double Function(int s)? accuracy,
  double? Function(int s)? speed,
}) {
  final fixes = <_Fix>[];
  for (var s = 0; s <= until; s++) {
    final n = noise?.call() ?? (y: 0.0, x: 0.0);
    if (s % every != 0) continue;
    final p = path(s);
    fixes.add((
      y: p.y + n.y,
      x: p.x + n.x,
      s: s,
      accuracy: accuracy?.call(s) ?? 6,
      speed: speed?.call(s),
    ));
  }
  return fixes;
}

/// Walk [walk1] s, stand [stop] s, then walk on at [pace] m/s along x.
({double y, double x}) Function(int s) _walkStopWalk(
  int walk1,
  int stop,
  double pace,
) {
  return (s) {
    final moving = s <= walk1 ? s : math.max(walk1, s - stop);
    return (y: 0.0, x: pace * moving);
  };
}

/// Wi-Fi positioning indoors: white noise σ 1.5 m (accuracy 6), and at
/// [perMinute] jumps per minute the position sits 30–60 m off for 1–10 s
/// (accuracy 25–35 m).
List<_Fix> _wifiJumps(
  math.Random r, {
  required int until,
  double perMinute = 0.5,
}) {
  final fixes = <_Fix>[];
  var jumpLeft = 0;
  var jy = 0.0, jx = 0.0, ja = 0.0;
  for (var s = 0; s <= until; s++) {
    if (jumpLeft == 0 && r.nextDouble() < perMinute / 60) {
      jumpLeft = 1 + r.nextInt(10);
      final d = 30 + 30 * r.nextDouble();
      final a = 2 * math.pi * r.nextDouble();
      jy = d * math.sin(a);
      jx = d * math.cos(a);
      ja = 25 + 10 * r.nextDouble();
    }
    final n = (y: 1.5 * _gauss(r), x: 1.5 * _gauss(r));
    final jumping = jumpLeft > 0;
    if (jumping) jumpLeft--;
    fixes.add((
      y: n.y + (jumping ? jy : 0),
      x: n.x + (jumping ? jx : 0),
      s: s,
      accuracy: jumping ? ja : 6,
      speed: null,
    ));
  }
  return fixes;
}

/// Zigzag around blocks: 30 m east, 30 m north, 30 m west, 30 m north, …
/// at [pace] m/s — the true position after [metres] along that path.
({double y, double x}) _zigzagAt(double metres) {
  const leg = 30.0;
  final n = (metres / leg).floor();
  final along = metres - n * leg;
  final rows = n ~/ 2; // completed north legs before this one
  final y = rows * leg + (n.isOdd ? along : 0);
  final x = switch (n % 4) {
    0 => along,
    1 => leg,
    2 => leg - along,
    _ => 0.0,
  };
  return (y: y, x: x);
}

/// Longest straight segment of a recorded route.
double _longestSegment(_Result r) {
  var longest = 0.0;
  for (var i = 1; i < r.trackPoints.length; i++) {
    final a = r.trackPoints[i - 1], b = r.trackPoints[i];
    longest = math.max(
      longest,
      const _PlaneCalc().distanceBetween(a.lat, a.lng, b.lat, b.lng),
    );
  }
  return longest;
}

void main() {
  group('standing still', () {
    test('white noise (σ 1.5 m) for 15 minutes adds no distance', () {
      for (var seed = 0; seed < _seeds; seed++) {
        final r = _record(
          _stream(
            (_) => (y: 0, x: 0),
            until: 900,
            noise: _whiteNoise(math.Random(seed), 1.5),
          ),
        );
        expect(r.distance, 0, reason: 'seed $seed');
      }
    });

    test('slow drift (OU, τ 30 s, σ 4 m) for 15 minutes adds at most what it '
        'did before #70', () {
      // Before #70 these seeds recorded [_driftBefore70] metres in total.
      var total = 0.0;
      for (var seed = 0; seed < _seeds; seed++) {
        total += _record(
          _stream(
            (_) => (y: 0, x: 0),
            until: 900,
            noise: _ouDrift(math.Random(seed), 4, 30),
          ),
        ).distance;
      }
      expect(total, lessThanOrEqualTo(_driftBefore70));
    });

    // A stop can last hours. Whatever noise gets recorded happens while the
    // last point is still fresh; after that, drift and jumps swing back
    // instead of confirming, so the distance stops growing.
    test('3 hours of drift (σ 4 m) or Wi-Fi jumps record nothing after the '
        'first 5 minutes', () {
      for (var seed = 0; seed < _seeds; seed++) {
        final drift = _record(
          _stream(
            (_) => (y: 0, x: 0),
            until: 3 * 3600,
            noise: _ouDrift(math.Random(seed), 4, 30),
          ),
        );
        final wifi = _record(_wifiJumps(math.Random(seed), until: 3 * 3600));
        expect(
          drift.recordedAt.where((s) => s > 300),
          isEmpty,
          reason: 'drift, seed $seed',
        );
        expect(
          wifi.recordedAt.where((s) => s > 300),
          isEmpty,
          reason: 'Wi-Fi, seed $seed',
        );
      }
    });

    test('3 hours of slow multipath drift (σ 8 m, τ 120 s, accuracy 20 m) '
        'add no distance', () {
      for (var seed = 0; seed < _seeds; seed++) {
        final r = _record(
          _stream(
            (_) => (y: 0, x: 0),
            until: 3 * 3600,
            noise: _ouDrift(math.Random(seed), 8, 120),
            accuracy: (_) => 20,
          ),
        );
        expect(r.distance, 0, reason: 'seed $seed');
      }
    });

    test('a single 35 m Wi-Fi jump out and back after 15 minutes adds no '
        'distance', () {
      final r = _record(
        _stream(
          (s) => (y: 0, x: s > 900 && s <= 905 ? 35 : 0),
          until: 1200,
          accuracy: (s) => s > 900 && s <= 905 ? 30 : 6,
        ),
      );
      expect(r.distance, 0);
    });
  });

  group('walking on after a stop', () {
    const walk1 = 120, stop = 900, walk2 = 300, pace = 1.3;
    const restart = walk1 + stop;
    const walked = pace * (walk1 + walk2);

    void expectRecovers(_Result r, {required int within, String? reason}) {
      final after = r.recordedAt.where((s) => s > restart);
      expect(after, isNotEmpty, reason: reason);
      expect(after.first - restart, lessThanOrEqualTo(within), reason: reason);
      // Measured from the last recorded point, nothing walked goes missing.
      expect(r.distance, greaterThan(0.9 * walked), reason: reason);
    }

    test('bench: recorded again within 40 s, with GPS noise while sitting', () {
      for (var seed = 0; seed < _seeds; seed++) {
        final r = _record(
          _stream(
            _walkStopWalk(walk1, stop, pace),
            until: restart + walk2,
            noise: _whiteNoise(math.Random(seed), 1.5),
          ),
        );
        expectRecovers(r, within: 40, reason: 'seed $seed');
      }
    });

    test('Android stop: provider speed 0 while sitting, recorded again '
        'within 10 s', () {
      final r = _record(
        _stream(
          _walkStopWalk(walk1, stop, pace),
          until: restart + walk2,
          speed: (s) => s > walk1 && s <= restart ? 0 : pace,
        ),
      );
      expectRecovers(r, within: 10);
    });

    test('supermarket: indoor fixes too vague to record, recorded again '
        'within 40 s outside', () {
      final r = _record(
        _stream(
          _walkStopWalk(walk1, stop, pace),
          until: restart + walk2,
          accuracy: (s) => s > walk1 && s <= restart ? 60 : 6,
        ),
      );
      expectRecovers(r, within: 40);
    });

    for (final accuracy in [20.0, 30.0]) {
      test('city accuracy ±${accuracy.round()} m without provider speed: '
          'recorded again within 60 s', () {
        for (var seed = 0; seed < _seeds; seed++) {
          final r = _record(
            _stream(
              _walkStopWalk(walk1, stop, pace),
              until: restart + walk2,
              noise: _whiteNoise(math.Random(seed), 1.5),
              accuracy: (_) => accuracy,
            ),
          );
          expectRecovers(r, within: 60, reason: 'seed $seed');
        }
      });
    }

    for (final every in [5, 15, 30]) {
      test('fixes only every $every s (screen locked): bench and supermarket '
          'are recorded again within ${math.max(40, every + 30)} s', () {
        expectRecovers(
          _record(
            _stream(
              _walkStopWalk(walk1, stop, pace),
              until: restart + walk2,
              every: every,
            ),
          ),
          within: math.max(40, every + 30),
          reason: 'bench',
        );
        expectRecovers(
          _record(
            _stream(
              _walkStopWalk(walk1, stop, pace),
              until: restart + walk2,
              every: every,
              accuracy: (s) => s > walk1 && s <= restart ? 60 : 6,
            ),
          ),
          within: math.max(40, every + 30),
          reason: 'supermarket',
        );
      });
    }
  });

  test('fixes only every 150 s while riding (aggressive battery saving) still '
      'record the ride', () {
    const pace = 5.0, ride = 1800;
    final r = _record(
      _stream((s) => (y: 0, x: pace * s), until: ride, every: 150),
    );
    expect(r.distance, greaterThan(0.85 * pace * ride));
  });

  // Android sometimes reports a valid speed ≥ 0.8 m/s for a single fix while
  // the phone lies still (multipath); one such spike must not count as
  // rolling on after a long stop.
  test('provider speed spikes while standing for an hour add no distance', () {
    for (var seed = 0; seed < _seeds; seed++) {
      final r = math.Random(seed);
      final drift = _ouDrift(r, 4, 30);
      final fixes = <_Fix>[
        for (var s = 0; s <= 3600; s++)
          (() {
            final p = drift();
            return (
              y: p.y,
              x: p.x,
              s: s,
              accuracy: 8.0,
              speed: (0.3 * _gauss(r)).abs(),
            );
          })(),
      ];
      expect(_record(fixes).distance, 0, reason: 'seed $seed');
    }
  });

  // After a stop, a skater weaving around 30 m blocks: the route must follow
  // the weave, not cut a straight line across the blocks. At 5 m/s the 8 m
  // displacement floor records every other fix anyway, so segments of up to
  // ~18 m are normal riding; a cut across a block would be 40 m or more.
  group('skating on after an hour\'s stop', () {
    const stop = 3600, ride = 120, pace = 5.0;
    const ridden = pace * ride;

    List<_Fix> skate({required bool withSpeed}) => _stream(
      (s) => s <= stop ? (y: 0, x: 0) : _zigzagAt(pace * (s - stop)),
      until: stop + ride,
      noise: _whiteNoise(math.Random(1), 1.5),
      speed: withSpeed ? (s) => s <= stop ? 0 : pace : null,
    );

    test('with provider speed: recorded again within 5 s and along the '
        'weave', () {
      final r = _record(skate(withSpeed: true));
      expect(
        r.recordedAt.where((s) => s > stop).first - stop,
        lessThanOrEqualTo(5),
      );
      expect(r.distance, greaterThan(0.9 * ridden));
      expect(_longestSegment(r), lessThan(20));
    });

    test('without provider speed: held fixes are filled in, so only the very '
        'first stretch from the stop point is straight', () {
      final r = _record(skate(withSpeed: false));
      expect(r.distance, greaterThan(0.85 * ridden));
      // The first point after the stop must clear 30 m (stage 4 over 60 s);
      // everything after it follows the weave.
      expect(_longestSegment(r), lessThan(40));
      // Nothing was recorded while standing, so every point after the start
      // belongs to the ride on.
      expect(r.recordedAt.where((s) => s > 0 && s <= stop), isEmpty);
      final afterStop = r.trackPoints.skip(1).toList();
      for (var i = 1; i < afterStop.length; i++) {
        final a = afterStop[i - 1], b = afterStop[i];
        expect(
          const _PlaneCalc().distanceBetween(a.lat, a.lng, b.lat, b.lng),
          lessThan(20),
          reason: 'segment $i',
        );
      }
    });
  });

  test('back-and-forth with a 10 s period (bowl) keeps its distance', () {
    // 20 m out, 20 m back, every 10 s, for 10 minutes: 4 m/s, 2400 m.
    final r = _record(
      _stream((s) => (y: 0, x: 20 - (20 - 4.0 * (s % 10)).abs()), until: 600),
    );
    expect(r.distance, greaterThanOrEqualTo(_bowlBefore70));
  });
}

/// Totals the pre-#70 filter recorded for the drift and bowl scenarios above
/// (measured once with the original stage 4 on these exact seeds/paths).
const double _driftBefore70 = 43.8; // 43.78 m over the 20 seeds
const double _bowlBefore70 = 1920;
