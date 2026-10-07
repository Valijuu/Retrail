import 'dart:math' as math;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:retrail/data/repositories/ride_repository.dart';
import 'package:retrail/data/repositories/trackpoint_repository.dart';
import 'package:retrail/domain/distance_calculator.dart';
import 'package:retrail/tracking/location_fix.dart';
import 'package:retrail/tracking/ride_tracker.dart';

// Seeded scenarios for stage 4 of the recording filter (#70): recording must
// pick up again quickly after a long stop or an indoor stretch, without
// turning GPS noise around someone standing still into distance.
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
typedef _Result = ({double distance, List<int> recordedAt});

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
    result = (distance: t.state.distanceMetres, recordedAt: recordedAt);
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

void main() {
  group('standing still for 15 minutes', () {
    test('white noise (σ 1.5 m) adds no distance', () {
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

    test(
      'slow drift (OU, τ 30 s, σ 4 m) adds at most what it did before #70',
      () {
        // Before #70 these seeds recorded [_driftBefore70] metres in total; a
        // segment longer than 60 s must clear 30 m, which drift of this spread
        // never does — so the total must not grow.
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
      },
    );
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

    test('bench: recorded again within 30 s, with GPS noise while sitting', () {
      for (var seed = 0; seed < _seeds; seed++) {
        final r = _record(
          _stream(
            _walkStopWalk(walk1, stop, pace),
            until: restart + walk2,
            noise: _whiteNoise(math.Random(seed), 1.5),
          ),
        );
        expectRecovers(r, within: 30, reason: 'seed $seed');
      }
    });

    test('Android stop: provider speed 0 while sitting, recorded again '
        'within 30 s', () {
      final r = _record(
        _stream(
          _walkStopWalk(walk1, stop, pace),
          until: restart + walk2,
          speed: (s) => s > walk1 && s <= restart ? 0 : pace,
        ),
      );
      expectRecovers(r, within: 30);
    });

    test('supermarket: indoor fixes too vague to record, recorded again '
        'within 30 s outside', () {
      final r = _record(
        _stream(
          _walkStopWalk(walk1, stop, pace),
          until: restart + walk2,
          accuracy: (s) => s > walk1 && s <= restart ? 60 : 6,
        ),
      );
      expectRecovers(r, within: 30);
    });

    for (final every in [5, 15, 30]) {
      test('fixes only every $every s (screen locked): bench and supermarket '
          'are recorded again within ${every + 30} s', () {
        expectRecovers(
          _record(
            _stream(
              _walkStopWalk(walk1, stop, pace),
              until: restart + walk2,
              every: every,
            ),
          ),
          within: every + 30,
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
          within: every + 30,
          reason: 'supermarket',
        );
      });
    }
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
/// (measured once with the uncapped stage 4 on these exact seeds/paths).
const double _driftBefore70 = 43.8; // 43.78 m over the 20 seeds
const double _bowlBefore70 = 1920;
