import 'dart:math' as math;

import 'package:retrail/domain/follow_direction.dart';
import 'package:retrail/domain/follow_tracker.dart';
import 'package:retrail/domain/heading.dart' show LatLng;
import 'package:retrail/domain/route_progress.dart';

/// Metres per degree of latitude for the Haversine radius (6371000 m).
const _mPerDeg = 6371000 * math.pi / 180;

/// A point [northM] metres north and [eastM] metres east of (48°, 11°).
LatLng at(double northM, double eastM) => (
  lat: 48.0 + northM / _mPerDeg,
  lng: 11.0 + eastM / (_mPerDeg * math.cos(48.0 * math.pi / 180)),
);

/// A position in local metres (north, east).
typedef Xy = ({double n, double e});

/// A reference route in local metres, with the [RouteTrack] the tracker sees.
class SimRoute {
  SimRoute(this.name, this.vertices)
    : track = RouteTrack([for (final v in vertices) at(v.n, v.e)]),
      cumulativeM = _cumulative(vertices);

  final String name;
  final List<Xy> vertices;
  final RouteTrack track;
  final List<double> cumulativeM;

  double get lengthM => cumulativeM.last;
  bool get isLoop => track.isLoop;

  static List<double> _cumulative(List<Xy> vs) {
    final out = [0.0];
    for (var i = 1; i < vs.length; i++) {
      out.add(out.last + _dist(vs[i - 1], vs[i]));
    }
    return out;
  }

  /// [s] on the route: wrapped round a loop, clamped to an open route.
  double wrap(double s) => isLoop
      ? ((s % lengthM) + lengthM) % lengthM
      : s.clamp(0.0, lengthM).toDouble();

  /// The leg index and its parameter at [s].
  (int, double) _legAt(double s) {
    final w = wrap(s);
    var i = 0;
    while (i < vertices.length - 2 && cumulativeM[i + 1] < w) {
      i++;
    }
    final len = cumulativeM[i + 1] - cumulativeM[i];
    return (i, len == 0 ? 0 : (w - cumulativeM[i]) / len);
  }

  Xy pointAt(double s) {
    final (i, t) = _legAt(s);
    final a = vertices[i], b = vertices[i + 1];
    return (n: a.n + (b.n - a.n) * t, e: a.e + (b.e - a.e) * t);
  }

  /// The unit normal at [s] pointing away from the vertex centroid.
  Xy outwardNormalAt(double s) {
    final (i, _) = _legAt(s);
    final a = vertices[i], b = vertices[i + 1];
    final len = _dist(a, b);
    var normal = (n: -(b.e - a.e) / len, e: (b.n - a.n) / len);
    final c = (
      n: vertices.map((v) => v.n).reduce((x, y) => x + y) / vertices.length,
      e: vertices.map((v) => v.e).reduce((x, y) => x + y) / vertices.length,
    );
    final p = pointAt(s);
    if ((p.n - c.n) * normal.n + (p.e - c.e) * normal.e < 0) {
      normal = (n: -normal.n, e: -normal.e);
    }
    return normal;
  }
}

double _dist(Xy a, Xy b) => math.sqrt(_sq(a.n - b.n) + _sq(a.e - b.e));
double _sq(double x) => x * x;

/// What the rider does, leg by leg, from [startS] (route metres, unwrapped:
/// on a loop it may run past either end).
class Plan {
  Plan(this.startS);

  final double startS;
  final List<_Leg> _legs = [];

  /// Rides along the route to [toS]; backwards when it lies behind.
  void ride(double toS) => _legs.add(_Ride(toS));

  /// Stands still for [seconds] fixes.
  void stand(int seconds) => _legs.add(_Stand(seconds));

  /// Leaves the route [depthM] away from it and comes back to the same spot.
  void excursion(double depthM) => _legs.add(_Excursion(depthM));

  /// Calls `flip()` [delay] fixes after the last fix so far.
  void flipAfter(int delay) => _legs.add(_Flip(delay));
}

sealed class _Leg {}

class _Ride extends _Leg {
  _Ride(this.toS);
  final double toS;
}

class _Stand extends _Leg {
  _Stand(this.seconds);
  final int seconds;
}

class _Excursion extends _Leg {
  _Excursion(this.depthM);
  final double depthM;
}

class _Flip extends _Leg {
  _Flip(this.delay);
  final int delay;
}

/// One 1 Hz fix of the true ride: position and route metres (unwrapped).
typedef TrueFix = ({Xy pos, double s});

/// The true ride of [plan] at [speed] m/s (±10 % per fix), and the fix index
/// after which `flip()` is called (null for none).
({List<TrueFix> fixes, int? flipAt}) generate(
  SimRoute route,
  Plan plan,
  double speed,
  math.Random r,
) {
  var s = plan.startS;
  final fixes = <TrueFix>[(pos: route.pointAt(s), s: s)];
  int? flipAt;
  double step() => speed * (0.9 + 0.2 * r.nextDouble());
  for (final leg in plan._legs) {
    switch (leg) {
      case _Ride(:final toS):
        final dir = toS > s ? 1 : -1;
        while (s != toS) {
          s = dir > 0 ? math.min(s + step(), toS) : math.max(s - step(), toS);
          fixes.add((pos: route.pointAt(s), s: s));
        }
      case _Stand(:final seconds):
        for (var i = 0; i < seconds; i++) {
          fixes.add((pos: route.pointAt(s), s: s));
        }
      case _Excursion(:final depthM):
        final base = route.pointAt(s), normal = route.outwardNormalAt(s);
        Xy off(double d) =>
            (n: base.n + normal.n * d, e: base.e + normal.e * d);
        var d = 0.0;
        while (d < depthM) {
          d = math.min(d + step(), depthM);
          fixes.add((pos: off(d), s: s));
        }
        while (d > 0) {
          d = math.max(d - step(), 0);
          fixes.add((pos: off(d), s: s));
        }
      case _Flip(:final delay):
        flipAt = fixes.length - 1 + delay;
    }
  }
  return (fixes: fixes, flipAt: flipAt);
}

/// A GPS error model: per run, a fresh source of per-fix errors.
class NoiseModel {
  const NoiseModel(this.name, this.maxFailureShare, this._source);

  final String name;

  /// The share of runs allowed to fail a scenario (the threshold).
  final double maxFailureShare;
  final Xy Function() Function(math.Random) _source;

  Xy Function() start(math.Random r) => _source(r);
}

double _gauss(math.Random r) {
  final u = 1 - r.nextDouble();
  return math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * r.nextDouble());
}

Xy Function() _none(math.Random _) =>
    () => (n: 0, e: 0);

Xy Function() Function(math.Random) _uniform(double halfM) =>
    (r) =>
        () => (
          n: (2 * r.nextDouble() - 1) * halfM,
          e: (2 * r.nextDouble() - 1) * halfM,
        );

Xy Function() Function(math.Random) _gaussian(double sigmaM) =>
    (r) =>
        () => (n: _gauss(r) * sigmaM, e: _gauss(r) * sigmaM);

/// GPS drift: per axis x ← ρ·x + N(0, σ), started in its stationary spread
/// σ/√(1 − ρ²) (≈ 6.9 m for σ 3, ρ 0.9).
Xy Function() Function(math.Random) _walk(double sigmaM, double rho) => (r) {
  final spread = sigmaM / math.sqrt(1 - rho * rho);
  var n = _gauss(r) * spread, e = _gauss(r) * spread;
  return () {
    n = rho * n + _gauss(r) * sigmaM;
    e = rho * e + _gauss(r) * sigmaM;
    return (n: n, e: e);
  };
};

const noiseless = NoiseModel('noiseless', 0, _none);
final noiseModels = [
  noiseless,
  NoiseModel('uniform ±5 m', 0.02, _uniform(5)),
  NoiseModel('gaussian σ5', 0.02, _gaussian(5)),
  NoiseModel('gaussian σ8', 0.05, _gaussian(8)),
  NoiseModel('correlated walk σ3 ρ0.9', 0.02, _walk(3, 0.9)),
];

/// What a run is checked for.
enum Metric {
  /// The direction at the end is the expected one.
  direction,

  /// Right before a scripted flip the direction is the expected first one.
  directionBeforeFlip,

  /// `remainingM` never exceeds the route (a loop: one lap).
  remaining,

  /// No "finished" (once decided) before the rider really reached the finish.
  earlyFinish,

  /// "Finished" at the end of a ride that ends at the finish.
  finishReached,

  /// The ridden intervals lie within [riddenSlackM] of the truly ridden road
  /// (on any pass of it, see [sameRoadM]).
  ridden,
}

/// Ridden intervals may reach this far along the route beyond the truly
/// ridden stretch.
const riddenSlackM = 40.0;

/// Another pass of the road the rider rode (an out-and-back's legs, a
/// lollipop's stem) counts as ridden within this of it.
const sameRoadM = 5.0;

/// GPS error allowance on the finish: an open route counts as reached within
/// [followFinishRadiusM] plus this of its end; a loop lap from
/// [followFinishMinShare] of its length less this.
const finishSlackM = 25.0;

/// Rider speed ranges at 1 Hz, m/s.
typedef Speed = ({double min, double max});
const Speed slow = (min: 1, max: 2);
const Speed cruise = (min: 3, max: 5);
const Speed fast = (min: 5, max: 8);

/// One rider behaviour on one route, run many times with seeded randomness.
class Scenario {
  Scenario(
    this.id, {
    required this.route,
    required this.plan,
    required this.expected,
    this.speed = cruise,
    this.endsAtFinish = false,
    this.metrics = Metric.values,
  });

  final String id;
  final SimRoute route;
  final Plan Function(math.Random r) plan;

  /// The direction at the end; before a scripted flip it is the opposite.
  final FollowDirection expected;
  final Speed speed;
  final bool endsAtFinish;
  final List<Metric> metrics;
}

FollowDirection _opposite(FollowDirection d) => d == FollowDirection.forward
    ? FollowDirection.reverse
    : FollowDirection.forward;

/// Deterministic seed for [label] (32-bit FNV-1a).
int seedOf(String label) {
  var h = 0x811c9dc5;
  for (final c in label.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  return h;
}

/// The metrics one seeded run of [sc] under [noise] fails. [log] receives
/// each failure as it happens, to replay a failing seed.
Set<Metric> runOnce(
  Scenario sc,
  NoiseModel noise,
  int seed, {
  void Function(String)? log,
}) {
  final r = math.Random(seed);
  final route = sc.route;
  final plan = sc.plan(r);
  final speed = sc.speed.min + (sc.speed.max - sc.speed.min) * r.nextDouble();
  final (:fixes, :flipAt) = generate(route, plan, speed, r);
  final error = noise.start(r);
  final failed = <Metric>{};
  final lengthM = route.track.lengthM;
  final ridden = _Coverage(route);
  final checkRidden = sc.metrics.contains(Metric.ridden);
  int? joinAt, flippedAt;
  var t = FollowTracker.start(route.track);
  for (var i = 0; i < fixes.length; i++) {
    final f = fixes[i], e = error();
    t = t.next(at(f.pos.n + e.n, f.pos.e + e.e));
    if (i == flipAt) {
      if (t.direction != _opposite(sc.expected)) {
        failed.add(Metric.directionBeforeFlip);
      }
      // The rider flips only when the direction shown is wrong.
      if (t.direction != sc.expected) {
        t = t.flip();
        flippedAt = i;
      }
    }
    final p = t.progress;
    if (p == null) continue;
    void fail(Metric m) {
      failed.add(m);
      log?.call(
        '${m.name} at fix $i: true s ${f.s.toStringAsFixed(1)}, '
        '${t.direction.name}, $p, ridden ${t.riddenIntervals}',
      );
    }

    if (p.hasJoined) joinAt ??= i;
    if (joinAt != null) ridden.add(f.s);
    if (p.remainingM > lengthM + 0.5) fail(Metric.remaining);
    // While undecided the UI shows the route's total length, not "finished".
    if (p.isFinished &&
        t.direction != FollowDirection.undecided &&
        !_finishAllowed(sc, fixes, i, joinAt, flippedAt)) {
      fail(Metric.earlyFinish);
    }
    if (checkRidden && !ridden.covers(t.riddenIntervals)) {
      fail(Metric.ridden);
    }
  }
  if (t.direction != sc.expected) failed.add(Metric.direction);
  if (sc.endsAtFinish && !(t.progress?.isFinished ?? false)) {
    failed.add(Metric.finishReached);
  }
  log?.call(
    'end: failed ${failed.map((m) => m.name)}, ${t.direction.name}, '
    '${t.progress}, ridden ${t.riddenIntervals}',
  );
  return failed.intersection(sc.metrics.toSet());
}

/// True when the rider has really reached the finish at fix [i].
bool _finishAllowed(
  Scenario sc,
  List<TrueFix> fixes,
  int i,
  int? joinAt,
  int? flipAt,
) {
  final route = sc.route;
  final flipped = flipAt != null && i >= flipAt;
  final d = flipAt == null || flipped ? sc.expected : _opposite(sc.expected);
  final sign = d == FollowDirection.forward ? 1 : -1;
  if (route.isLoop) {
    final ref = flipped ? flipAt : joinAt!;
    final lapM = (fixes[i].s - fixes[ref].s) * sign;
    return lapM >= followFinishMinShare * route.lengthM - finishSlackM;
  }
  final s = route.wrap(fixes[i].s);
  final toFinish = sign > 0 ? route.lengthM - s : s;
  return toFinish <= followFinishRadiusM + finishSlackM;
}

/// The truly ridden stretch since the join, in unwrapped route metres: the
/// rider's route position moves continuously, so it is one range.
class _Coverage {
  _Coverage(this.route);

  final SimRoute route;
  double? _lo, _hi;

  void add(double s) {
    _lo = math.min(_lo ?? s, s);
    _hi = math.max(_hi ?? s, s);
  }

  /// True when every part of [intervals] lies within [riddenSlackM] along
  /// the route of the ridden road: the ridden stretch, or another pass of the
  /// same road within [sameRoadM] of it (an out-and-back's legs, a lollipop's
  /// stem).
  bool covers(List<(double, double)> intervals) {
    for (final (from, to) in intervals) {
      if (_alongCovers(from, to)) continue;
      for (var k = (from / _sampleM).ceil(); k * _sampleM < to; k++) {
        if (!_coversSample(k)) return false;
      }
      if (!_coversPoint(from) || !_coversPoint(to)) return false;
    }
    return true;
  }

  /// Sample spacing along the route.
  static const _sampleM = 2.0;

  int get _sampleCount => (route.lengthM / _sampleM).ceil();

  /// Samples known to lie on the ridden road, and samples known to be
  /// covered: both only grow with the ridden stretch.
  final Set<int> _ridden = {}, _covered = {};

  bool _coversSample(int k) {
    if (_covered.contains(k)) return true;
    final covered = _coversPoint(k * _sampleM);
    if (covered) _covered.add(k);
    return covered;
  }

  bool _coversPoint(double m) {
    if (_alongCovers(m, m)) return true;
    final k0 = (m / _sampleM).round(), reach = riddenSlackM ~/ _sampleM;
    int wrapped(int k) => route.isLoop ? k % _sampleCount : k;
    for (var j = -reach; j <= reach; j++) {
      if (_ridden.contains(wrapped(k0 + j))) return true;
    }
    for (var j = 0; j <= reach; j++) {
      if (_onRiddenRoad(wrapped(k0 + j)) || _onRiddenRoad(wrapped(k0 - j))) {
        return true;
      }
    }
    return false;
  }

  bool _onRiddenRoad(int k) {
    if (_ridden.contains(k)) return true;
    final m = k * _sampleM;
    if (!route.isLoop && (m < 0 || m > route.lengthM)) return false;
    final onIt = _distanceToRidden(route.pointAt(m)) <= sameRoadM;
    if (onIt) _ridden.add(k);
    return onIt;
  }

  bool _alongCovers(double from, double to) {
    final lo = _lo, hi = _hi;
    if (lo == null || hi == null) return false;
    final dLo = lo - riddenSlackM, dHi = hi + riddenSlackM;
    if (!route.isLoop) return from >= dLo && to <= dHi;
    final lapM = route.lengthM;
    if (dHi - dLo >= lapM) return true;
    for (var k = ((dLo - to) / lapM).floor(); k * lapM + from <= dHi; k++) {
      if (from + k * lapM >= dLo && to + k * lapM <= dHi) return true;
    }
    return false;
  }

  /// Distance from [p] to the route along the ridden stretch.
  double _distanceToRidden(Xy p) {
    final lo = _lo, hi = _hi;
    if (lo == null || hi == null) return double.infinity;
    final lapM = route.lengthM, cum = route.cumulativeM, vs = route.vertices;
    var best = double.infinity;
    final firstLap = route.isLoop ? (lo / lapM).floor() : 0;
    final lastLap = route.isLoop ? (hi / lapM).floor() : 0;
    for (var lap = firstLap; lap <= lastLap; lap++) {
      for (var i = 0; i < vs.length - 1; i++) {
        final a0 = cum[i] + lap * lapM, b0 = cum[i + 1] + lap * lapM;
        final from = math.max(a0, lo), to = math.min(b0, hi);
        if (from > to || b0 == a0) continue;
        final a = vs[i], b = vs[i + 1];
        final dn = b.n - a.n, de = b.e - a.e, len2 = dn * dn + de * de;
        final t = (((p.n - a.n) * dn + (p.e - a.e) * de) / len2).clamp(
          (from - a0) / (b0 - a0),
          (to - a0) / (b0 - a0),
        );
        best = math.min(best, _dist(p, (n: a.n + dn * t, e: a.e + de * t)));
      }
    }
    return best;
  }
}

/// Failure counts of [runs] seeded runs of [sc] under [noise].
class ScenarioResult {
  ScenarioResult(this.runs);

  final int runs;
  int failedRuns = 0;
  final Map<Metric, int> byMetric = {};

  /// The first failing seed, to replay one run.
  int? firstFailingSeed;

  @override
  String toString() {
    final parts = [
      for (final m in Metric.values)
        if ((byMetric[m] ?? 0) > 0) '${m.name} ${byMetric[m]}',
    ];
    return '$failedRuns/$runs failed'
        '${parts.isEmpty ? '' : ' (${parts.join(', ')})'}'
        '${firstFailingSeed == null ? '' : ', first seed $firstFailingSeed'}';
  }
}

ScenarioResult runScenario(Scenario sc, NoiseModel noise, int runs) {
  final result = ScenarioResult(runs);
  for (var k = 0; k < runs; k++) {
    final seed = seedOf('${sc.id}|${noise.name}|$k');
    final failed = runOnce(sc, noise, seed);
    if (failed.isEmpty) continue;
    result.failedRuns++;
    result.firstFailingSeed ??= seed;
    for (final m in failed) {
      result.byMetric[m] = (result.byMetric[m] ?? 0) + 1;
    }
  }
  return result;
}
