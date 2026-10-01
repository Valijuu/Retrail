import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/follow_direction.dart';

import 'support/follow_scenarios_baseline.dart';
import 'support/real_rides.dart';
import 'support/sim_metrics.dart';
import 'support/sim_noise.dart';
import 'support/sim_route.dart';

// The statistical yardstick for the follow direction/progress tracker
// (Spec 18): seeded rides over six route shapes under five GPS noise models,
// plus a local-only replay of real rides. Every change to FollowTracker must
// keep the whole suite green.
//
// Tiers: the gate models (noiseless, uniform ±5 m, Gaussian σ5, correlated
// walk; 200 runs) must stay under their thresholds. The stress model
// (Gaussian σ8; 100 runs) may fail ≤ 15 % of runs and no more than its
// committed baseline + 3 (support/follow_scenarios_baseline.dart); the
// long-term target is 5 %. The local real-ride group also replays each
// ride along its own geometry under the gate noise models, with the gate
// thresholds.
//
//   --dart-define=FOLLOW_SCENARIOS_ALL=true    also run the baseline-RED pairs
//   --dart-define=FOLLOW_SCENARIOS_PRINT=true  print every pair's counts
//   --dart-define=FOLLOW_SCENARIOS_REPLAY='<scenario id>|<noise>|<seed>'
//       replay one run with a per-fix log (seeds are in failure messages);
//       a real-ride case id ('ride …') replays a noisy real-ride run

const _runAll = bool.fromEnvironment('FOLLOW_SCENARIOS_ALL');
const _printCounts = bool.fromEnvironment('FOLLOW_SCENARIOS_PRINT');
const _replay = String.fromEnvironment('FOLLOW_SCENARIOS_REPLAY');
const _baselineRed = 'baseline RED — fixed in Task 8';

/// Seeded runs per real ride and gate noise model.
const _realNoiseRuns = 200;

const _u5 = 'uniform ±5 m', _g5 = 'gaussian σ5', _g8 = 'gaussian σ8';
const _walk = 'correlated walk σ3 ρ0.9';

/// Scenario → the noise models it fails its threshold under at the Task 7
/// baseline, skipped until Task 8 fixes them.
const _red = <String, Set<String>>{
  'L-shape · mid-route backward · slow': {_g5, _g8},
  'L-shape · stand 10s at the join, then backward · cruise': {_g5, _g8, _walk},
  'L-shape · stand 30s at the join, then forward · cruise': {_g8},
  'L-shape · stand 30s at the join, then backward · cruise': {_g5, _g8, _walk},
  'L-shape · stand 60s at the join, then forward · cruise': {_g8, _walk},
  'L-shape · stand 60s at the join, then backward · cruise': {_g5, _g8, _walk},
  'square · forward from 2–20 m past the start · cruise': {_g8},
  'square · reverse from the finish · cruise': {_g8, _walk},
  'square · mid-route forward · cruise': {_g8, _walk},
  'square · mid-route backward · cruise': {_g8, _walk},
  'square · across the seam forward · cruise': {_g8, _walk},
  'square · across the seam backward · cruise': {_g8, _walk},
  'square · mid-route forward · slow': {_g8, _walk},
  'square · mid-route backward · slow': {_g5, _g8, _walk},
  'square · mid-route forward · fast': {_walk},
  'square · mid-route backward · fast': {_g8},
  'square · stand 10s at the join, then forward · cruise': {_g8, _walk},
  'square · stand 10s at the join, then backward · cruise': {_g5, _g8, _walk},
  'square · stand 30s at the join, then forward · cruise': {_g8, _walk},
  'square · stand 30s at the join, then backward · cruise': {_g5, _g8, _walk},
  'square · stand 60s at the join, then forward · cruise': {_g5, _g8, _walk},
  'square · stand 60s at the join, then backward · cruise': {_g5, _g8, _walk},
  'square · flip mid-ride, one lap back · cruise': {_g8, _walk},
  '2 km loop · reverse from the finish · fast': {_g8, _walk},
  '2 km loop · across the seam forward · cruise': {_walk},
  '2 km loop · across the seam backward · cruise': {_g8},
  '2 km loop · mid-route backward · slow': {_g5, _g8, _walk},
  '2 km loop · stand 30s at the join, then backward · cruise': {
    _g5,
    _g8,
    _walk,
  },
  'out-and-back · forward from 2–20 m past the start · cruise': {
    _u5,
    _g5,
    _g8,
    _walk,
  },
  'out-and-back · forward from 2–20 m past the start · slow': {
    _u5,
    _g5,
    _g8,
    _walk,
  },
  'out-and-back · forward from 2–20 m past the start · fast': {_u5, _g5, _g8},
  'out-and-back · mid-route forward (way out) · cruise': {_u5, _g5, _g8, _walk},
  'out-and-back · stand 10s at the join, then forward · cruise': {
    _u5,
    _g5,
    _g8,
    _walk,
  },
  'out-and-back · stand 30s at the join, then forward · cruise': {
    _u5,
    _g5,
    _g8,
    _walk,
  },
  'out-and-back · stand 60s at the join, then forward · cruise': {
    _u5,
    _g5,
    _g8,
    _walk,
  },
  'lollipop · forward from 2–20 m past the start · cruise': {_g5, _g8, _walk},
  'lollipop · mid-loop forward · cruise': {_u5, _g5, _g8, _walk},
  'lollipop · mid-loop backward · cruise': {_u5, _g5, _g8, _walk},
  'lollipop · stand 30s at the join, then forward · cruise': {
    _u5,
    _g5,
    _g8,
    _walk,
  },
  'lollipop · stand 30s at the join, then backward · cruise': {
    _u5,
    _g5,
    _g8,
    _walk,
  },
  'lollipop · joined at the start/finish, ridden reverse: forward by default, flipped at the top of the stem · cruise':
      {_u5, _g5, _g8, _walk},
  'out-and-back 1 km · forward from 2–20 m past the start · cruise': {
    _u5,
    _g5,
    _g8,
    _walk,
  },
  'out-and-back 1 km · forward 200 m from 2–20 m past the start · slow': {
    _g5,
    _g8,
    _walk,
  },
  'out-and-back 1 km · mid-route forward (way out) · cruise': {
    _u5,
    _g5,
    _g8,
    _walk,
  },
  'out-and-back 1 km · stand 30s at the join, then forward · cruise': {
    _u5,
    _g5,
    _g8,
    _walk,
  },
};

/// Real-ride cases failing at the Task 7 baseline, skipped until Task 8.
const _redReal = <String>{};

/// Noisy real-ride runs failing at the Task 8 baseline (before the tracker
/// rework), skipped until it lands.
const _redRealNoise = <String>{
  'ride 6 · across the seam reversed · correlated walk σ3 ρ0.9',
  'ride 6 · across the seam reversed · gaussian σ5',
  'ride 6 · across the seam reversed · uniform ±5 m',
  'ride 6 · across the seam · correlated walk σ3 ρ0.9',
  'ride 6 · across the seam · gaussian σ5',
  'ride 6 · across the seam · uniform ±5 m',
  'ride 6 · itself from the start · correlated walk σ3 ρ0.9',
  'ride 6 · itself from the start · gaussian σ5',
  'ride 6 · itself from the start · uniform ±5 m',
  'ride 6 · reversed from 60 % · correlated walk σ3 ρ0.9',
  'ride 6 · reversed from 60 % · gaussian σ5',
  'ride 6 · reversed from 60 % · uniform ±5 m',
  'ride 6 · reversed from the finish · correlated walk σ3 ρ0.9',
  'ride 6 · reversed from the finish · gaussian σ5',
  'ride 6 · reversed from the finish · uniform ±5 m',
  'ride 7 · itself from 40 % · correlated walk σ3 ρ0.9',
  'ride 7 · itself from the start · correlated walk σ3 ρ0.9',
  'ride 7 · reversed from the finish · correlated walk σ3 ρ0.9',
};

const _fwd = FollowDirection.forward;
const _rev = FollowDirection.reverse;

Xy _p(double n, double e) => (n: n, e: e);

/// An open L: 800 m north, then 800 m east. L = 1600 m.
final _lShape = SimRoute('L-shape', [_p(0, 0), _p(800, 0), _p(800, 800)]);

/// A closed 100 m square. L = 400 m.
final _square = SimRoute('square', [
  _p(0, 0),
  _p(100, 0),
  _p(100, 100),
  _p(0, 100),
  _p(0, 0),
]);

/// A closed five-sided loop. L ≈ 2083 m.
final _loop2k = SimRoute('2 km loop', [
  _p(0, 0),
  _p(600, 0),
  _p(600, 500),
  _p(200, 500),
  _p(0, 300),
  _p(0, 0),
]);

/// 200 m north and back south 3 m east of the way out (a loop: its ends are
/// 3 m apart). L ≈ 400 m.
final _outAndBack = SimRoute('out-and-back', [_p(0, 0), _p(200, 0), _p(0, 3)]);

/// A 300 m stem north, a 200 m square at its top, the stem back. L = 1400 m.
final _lollipop = SimRoute('lollipop', [
  _p(0, 0),
  _p(300, 0),
  _p(500, 0),
  _p(500, 200),
  _p(300, 200),
  _p(300, 0),
  _p(0, 0),
]);

/// 300 m north, 200 m east, and the same way back 3 m off. L ≈ 1003 m.
final _outAndBack1k = SimRoute('out-and-back 1 km', [
  _p(0, 0),
  _p(300, 0),
  _p(300, 200),
  _p(303, 200),
  _p(303, 3),
  _p(0, 3),
]);

double _u(math.Random r, double lo, double hi) =>
    lo + (hi - lo) * r.nextDouble();

String _speedName(Speed s) => s == slow
    ? 'slow'
    : s == fast
    ? 'fast'
    : 'cruise';

/// Joins [route] 2–20 m past its start and rides forward to its end (a loop:
/// one lap back to the join).
Scenario _fromStart(SimRoute route, {Speed speed = cruise}) => Scenario(
  '${route.name} · forward from 2–20 m past the start · ${_speedName(speed)}',
  route: route,
  speed: speed,
  expected: _fwd,
  endsAtFinish: true,
  plan: (r) {
    final s0 = _u(r, 2, 20);
    return Plan(s0)
      ..ride(route.isLoop ? s0 + route.lengthM : route.lengthM)
      ..stand(3);
  },
);

/// Joins [route] 2–20 m before its finish and rides it backwards to the
/// start (a loop: one lap back to the join).
Scenario _fromFinish(SimRoute route, {Speed speed = cruise}) => Scenario(
  '${route.name} · reverse from the finish · ${_speedName(speed)}',
  route: route,
  speed: speed,
  expected: _rev,
  endsAtFinish: true,
  plan: (r) {
    final s0 = route.lengthM - _u(r, 2, 20);
    return Plan(s0)
      ..ride(route.isLoop ? s0 - route.lengthM : 0)
      ..stand(3);
  },
);

/// Joins [route] between [lo] and [hi] (route metres) and rides [d] after
/// standing still [standS] seconds: [rideM] metres, or to the finish (a
/// loop: one lap) when null.
Scenario _mid(
  SimRoute route,
  FollowDirection d, {
  required double lo,
  required double hi,
  Speed speed = cruise,
  int standS = 0,
  double? rideM,
  String? what,
}) {
  final way = d == _fwd ? 'forward' : 'backward';
  final label =
      what ??
      (standS > 0
          ? 'stand ${standS}s at the join, then $way'
          : 'mid-route $way');
  return Scenario(
    '${route.name} · $label · ${_speedName(speed)}',
    route: route,
    speed: speed,
    expected: d,
    endsAtFinish: rideM == null,
    plan: (r) {
      final s0 = _u(r, lo, hi);
      final sign = d == _fwd ? 1 : -1;
      final toS = rideM != null
          ? s0 + sign * rideM
          : route.isLoop
          ? s0 + sign * route.lengthM
          : d == _fwd
          ? route.lengthM
          : 0.0;
      final plan = Plan(s0);
      if (standS > 0) plan.stand(standS);
      plan.ride(toS);
      if (rideM == null) plan.stand(3);
      return plan;
    },
  );
}

final _scenarios = <Scenario>[
  // Open L-shape.
  _fromStart(_lShape),
  _fromFinish(_lShape),
  _mid(_lShape, _fwd, lo: 480, hi: 960),
  _mid(_lShape, _rev, lo: 480, hi: 960),
  _mid(_lShape, _fwd, lo: 480, hi: 960, speed: slow, rideM: 200),
  _mid(_lShape, _rev, lo: 480, hi: 960, speed: slow, rideM: 200),
  _mid(_lShape, _fwd, lo: 480, hi: 960, speed: fast),
  _mid(_lShape, _rev, lo: 480, hi: 960, speed: fast),
  for (final standS in [10, 30, 60])
    for (final d in [_fwd, _rev])
      _mid(_lShape, d, lo: 480, hi: 960, standS: standS, rideM: 300),
  Scenario(
    'L-shape · 50 m off-route excursion · cruise',
    route: _lShape,
    expected: _fwd,
    endsAtFinish: true,
    plan: (r) {
      final s0 = _u(r, 300, 500);
      return Plan(s0)
        ..ride(s0 + 200)
        ..excursion(50)
        ..ride(_lShape.lengthM)
        ..stand(3);
    },
  ),
  Scenario(
    'L-shape · flip mid-ride, back to the start · cruise',
    route: _lShape,
    expected: _rev,
    endsAtFinish: true,
    plan: (r) {
      final s0 = _u(r, 480, 800);
      return Plan(s0)
        ..ride(s0 + 200)
        ..flipAfter(3)
        ..ride(0)
        ..stand(3);
    },
  ),

  // Square loop, 400 m.
  _fromStart(_square),
  _fromFinish(_square),
  _mid(_square, _fwd, lo: 120, hi: 280),
  _mid(_square, _rev, lo: 120, hi: 280),
  _mid(_square, _fwd, lo: 340, hi: 380, what: 'across the seam forward'),
  _mid(_square, _rev, lo: 20, hi: 60, what: 'across the seam backward'),
  _mid(_square, _fwd, lo: 120, hi: 280, speed: slow),
  _mid(_square, _rev, lo: 120, hi: 280, speed: slow),
  _mid(_square, _fwd, lo: 120, hi: 280, speed: fast),
  _mid(_square, _rev, lo: 120, hi: 280, speed: fast),
  for (final standS in [10, 30, 60])
    for (final d in [_fwd, _rev])
      _mid(_square, d, lo: 120, hi: 280, standS: standS),
  Scenario(
    'square · flip mid-ride, one lap back · cruise',
    route: _square,
    expected: _rev,
    endsAtFinish: true,
    plan: (r) {
      final s0 = _u(r, 120, 280);
      // The flip starts a fresh lap 3 fixes after the turn: ride one lap
      // back from the turn, plus a little.
      return Plan(s0)
        ..ride(s0 + 100)
        ..flipAfter(3)
        ..ride(s0 + 100 - _square.lengthM - 10)
        ..stand(3);
    },
  ),

  // 2 km loop.
  _fromStart(_loop2k),
  _fromFinish(_loop2k, speed: fast),
  _mid(
    _loop2k,
    _fwd,
    lo: 2023,
    hi: 2063,
    rideM: 300,
    what: 'across the seam forward',
  ),
  _mid(
    _loop2k,
    _rev,
    lo: 20,
    hi: 60,
    rideM: 300,
    what: 'across the seam backward',
  ),
  _mid(_loop2k, _rev, lo: 700, hi: 1300, speed: slow, rideM: 200),
  _mid(_loop2k, _rev, lo: 700, hi: 1300, standS: 30, rideM: 300),
  Scenario(
    '2 km loop · 50 m off-route excursion · cruise',
    route: _loop2k,
    expected: _fwd,
    plan: (r) {
      final s0 = _u(r, 700, 1000);
      return Plan(s0)
        ..ride(s0 + 200)
        ..excursion(50)
        ..ride(s0 + 400);
    },
  ),

  // Out-and-back on the same road, 400 m.
  _fromStart(_outAndBack),
  _fromStart(_outAndBack, speed: slow),
  _fromStart(_outAndBack, speed: fast),
  _mid(_outAndBack, _fwd, lo: 40, hi: 140, what: 'mid-route forward (way out)'),
  for (final standS in [10, 30, 60])
    _mid(_outAndBack, _fwd, lo: 2, hi: 20, standS: standS),

  // Lollipop.
  _fromStart(_lollipop),
  _mid(_lollipop, _fwd, lo: 500, hi: 900, what: 'mid-loop forward'),
  _mid(_lollipop, _rev, lo: 500, hi: 900, what: 'mid-loop backward'),
  _mid(_lollipop, _fwd, lo: 500, hi: 900, standS: 30),
  _mid(_lollipop, _rev, lo: 500, hi: 900, standS: 30),
  // The acknowledged ambiguity (Spec 18): joined exactly at the start/finish
  // and ridden the reverse way, the rider goes up the stem, which is the same
  // road either way. At the top of the stem forward (then flipped), reverse
  // decided on its own (no flip) and undecided (the flip forces reverse) are
  // all accepted, and "to go" is only checked from there on. A flip starts a
  // fresh lap (#55): "to go" then overstates by the stem and "finished" is
  // missing at the true end. The suite asserts that current behaviour: lap
  // and finish are measured from the flip.
  Scenario(
    'lollipop · joined at the start/finish, ridden reverse: forward by '
    'default, flipped at the top of the stem · cruise',
    route: _lollipop,
    expected: _rev,
    endsAtFinish: true,
    remainingBeforeFlip: false,
    metrics: const [
      Metric.direction,
      Metric.remaining,
      Metric.earlyFinish,
      Metric.finishReached,
      Metric.ridden,
    ],
    plan: (r) => Plan(_lollipop.lengthM)
      ..ride(_lollipop.lengthM - 300)
      ..flipAfter(0)
      ..ride(0)
      ..stand(3),
  ),

  // Out-and-back of 1 km.
  _fromStart(_outAndBack1k),
  _mid(
    _outAndBack1k,
    _fwd,
    lo: 2,
    hi: 20,
    speed: slow,
    rideM: 200,
    what: 'forward 200 m from 2–20 m past the start',
  ),
  _mid(
    _outAndBack1k,
    _fwd,
    lo: 100,
    hi: 250,
    what: 'mid-route forward (way out)',
  ),
  _mid(_outAndBack1k, _fwd, lo: 2, hi: 20, standS: 30),
];

void _log(String line) {
  // ignore: avoid_print
  print(line);
}

void main() {
  if (_replay.isNotEmpty) {
    test('replay $_replay', () {
      final [id, noiseName, seed] = _replay.split('|');
      final noise = noiseModels.firstWhere((n) => n.name == noiseName);
      final rides = loadRealRides();
      if (id.startsWith('ride ') && rides != null) {
        final rc = realCases(rides).firstWhere((c) => c.check.id == id);
        runRealNoisy(rc, noise, int.parse(seed), log: _log, trace: true);
        return;
      }
      final sc = _scenarios.firstWhere((s) => s.id == id);
      runOnce(sc, noise, int.parse(seed), log: _log, trace: true);
    });
    return;
  }

  for (final sc in _scenarios) {
    group(sc.id, () {
      for (final noise in noiseModels) {
        final key = '${sc.id} · ${noise.name}';
        test(
          noise.name,
          () {
            final result = runScenario(sc, noise);
            if (_printCounts) _log('RESULT $key: $result');
            final baseline = followScenariosBaseline[sc.id]?[noise.name];
            final allowed = noise.isStress && baseline != null
                ? math.min(noise.maxFailures, baseline + stressRatchetSlack)
                : noise.maxFailures;
            expect(
              result.failedRuns,
              lessThanOrEqualTo(allowed),
              reason:
                  '$key: $result, allowed $allowed'
                  '${baseline == null ? '' : ' (baseline $baseline)'}',
            );
          },
          skip: !_runAll && (_red[sc.id]?.contains(noise.name) ?? false)
              ? _baselineRed
              : false,
        );
      }
    });
  }

  group('suite bookkeeping', () {
    final ids = {for (final sc in _scenarios) sc.id};

    test('scenario ids are unique', () {
      expect(ids, hasLength(_scenarios.length));
    });

    test('every baseline-RED key names a scenario and a noise model', () {
      final noiseNames = {for (final n in noiseModels) n.name};
      for (final MapEntry(:key, :value) in _red.entries) {
        expect(ids, contains(key));
        expect(noiseNames, containsAll(value), reason: key);
      }
    });

    test('the committed baseline covers every scenario and noise model', () {
      expect(followScenariosBaseline.keys.toSet(), ids);
      for (final counts in followScenariosBaseline.values) {
        expect(counts.keys.toSet(), {for (final n in noiseModels) n.name});
      }
    });
  });

  final rides = loadRealRides();
  group('real rides (local)', () {
    if (rides == null) {
      test(
        'replay',
        () {},
        skip: 'real-ride fixture not present — local-only replay',
      );
      return;
    }
    final cases = realCases(rides);
    test('every baseline-RED real-ride key names a case', () {
      final ids = {for (final c in cases) c.check.id};
      expect(ids, containsAll(_redReal));
      final noisy = {
        for (final id in ids)
          for (final n in noiseModels) '$id · ${n.name}',
      };
      expect(noisy, containsAll(_redRealNoise));
    });
    for (final rc in cases) {
      test(
        rc.check.id,
        () {
          final lines = <String>[];
          final failed = runReal(rc, log: lines.add);
          if (_printCounts) _log('REAL ${rc.check.id}: ${lines.join(' | ')}');
          expect(failed, isEmpty, reason: lines.join('\n'));
        },
        skip: !_runAll && _redReal.contains(rc.check.id) ? _baselineRed : false,
      );
    }
  });

  group('real rides + seeded noise (local)', () {
    if (rides == null) {
      test(
        'replay',
        () {},
        skip: 'real-ride fixture not present — local-only replay',
      );
      return;
    }
    final selfReplays = [
      for (final rc in realCases(rides))
        if (rc.trueS != null) rc,
    ];
    for (final rc in selfReplays) {
      for (final noise in noiseModels) {
        if (noise == noiseless || noise.isStress) continue;
        final key = '${rc.check.id} · ${noise.name}';
        test(
          key,
          () {
            final allowed = (noise.maxFailureShare * _realNoiseRuns).floor();
            var failedRuns = 0;
            int? firstSeed;
            for (var k = 0; k < _realNoiseRuns; k++) {
              final seed = seedOf('$key|$k');
              if (runRealNoisy(rc, noise, seed).isEmpty) continue;
              failedRuns++;
              firstSeed ??= seed;
            }
            final result =
                '$failedRuns/$_realNoiseRuns failed'
                '${firstSeed == null ? '' : ', first seed $firstSeed'}';
            if (_printCounts) _log('REALNOISE $key: $result');
            expect(
              failedRuns,
              lessThanOrEqualTo(allowed),
              reason: '$key: $result, allowed $allowed',
            );
          },
          skip: !_runAll && _redRealNoise.contains(key) ? _baselineRed : false,
        );
      }
    }
  });
}
