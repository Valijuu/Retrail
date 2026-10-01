import 'dart:math' as math;

import 'package:retrail/domain/follow_direction.dart';
import 'package:retrail/domain/follow_tracker.dart';
import 'package:retrail/domain/route_progress.dart';

import 'sim_coverage.dart';
import 'sim_noise.dart';
import 'sim_route.dart';

/// What a followed ride is checked for.
enum Metric {
  /// The direction at the end is the expected one (on a same-road route,
  /// either decided direction).
  direction,

  /// Right before a scripted flip the direction is the expected first one.
  directionBeforeFlip,

  /// Once decided and not finished, "to go" is within [remainingSlackM] of
  /// the true distance left (a loop: one lap from the join, or from a flip).
  remaining,

  /// No "finished" (once decided) before the rider really reached the finish
  /// (within the finish radius plus [finishSlackM]).
  earlyFinish,

  /// "Finished" at the end of a ride that really ends at the finish.
  finishReached,

  /// The ridden intervals lie within [riddenSlackM] of the truly ridden road
  /// (on any pass of it, see [sameRoadM]).
  ridden,
}

/// "To go" may be off by this much.
const remainingSlackM = 40.0;

/// GPS error allowance on the finish: an open route counts as reached within
/// [followFinishRadiusM] plus this of its end; a loop lap from
/// [followFinishMinShare] of its length less this.
const finishSlackM = 25.0;

/// A ride followed along [route] and what it is checked for.
class FollowCase {
  FollowCase(
    this.id, {
    required this.route,
    required this.expected,
    this.endsAtFinish = false,
    this.metrics = Metric.values,
    this.remainingBeforeFlip = true,
  });

  final String id;
  final SimRoute route;

  /// The direction at the end; before a scripted flip it is the opposite.
  /// On a same-road route ([SimRoute.isSameRoad]) either direction counts,
  /// and this is only the way the rider rides.
  final FollowDirection expected;

  /// The ride ends at the finish (a loop: a lap from the join or the flip).
  final bool endsAtFinish;
  final List<Metric> metrics;

  /// Check "to go" before a scripted flip too. Off where the orientation
  /// before the flip is ambiguous (a lollipop's stem).
  final bool remainingBeforeFlip;
}

/// One rider behaviour on one route, run many times with seeded randomness.
class Scenario extends FollowCase {
  Scenario(
    super.id, {
    required super.route,
    required this.plan,
    required super.expected,
    this.speed = cruise,
    super.endsAtFinish,
    super.metrics,
    super.remainingBeforeFlip,
  });

  final Plan Function(math.Random r) plan;
  final Speed speed;
}

FollowDirection _opposite(FollowDirection d) => d == FollowDirection.forward
    ? FollowDirection.reverse
    : FollowDirection.forward;

/// Follows [c.route] with the GPS fixes [measured] (local metres) while the
/// rider really is at route metres [trueS] (unwrapped), calling `flip()` at
/// fix [flipAt] when the direction shown is wrong. Returns the failed
/// metrics. [log] receives each failure, and with [trace] every fix (route
/// metres only, never positions).
Set<Metric> evaluate(
  FollowCase c,
  List<double> trueS,
  List<Xy> measured,
  int? flipAt, {
  void Function(String)? log,
  bool trace = false,
}) {
  final route = c.route;
  final lengthM = route.lengthM;
  final failed = <Metric>{};
  final ridden = Coverage(route);
  final checkRidden = c.metrics.contains(Metric.ridden);
  int? joinAt, flippedAt;

  /// The orientation the rider should see at fix [i] and how far along a
  /// loop's lap (from the join, or from the flip) the rider really is.
  ({FollowDirection d, double lapM}) truth(int i) {
    final beforeFlip = flipAt != null && i < flipAt;
    final d = beforeFlip ? _opposite(c.expected) : c.expected;
    final ref = flippedAt != null && i >= flippedAt ? flippedAt : joinAt!;
    final sign = d == FollowDirection.forward ? 1 : -1;
    return (d: d, lapM: (trueS[i] - trueS[ref]) * sign);
  }

  double trueRemaining(int i) {
    final (:d, :lapM) = truth(i);
    if (route.isLoop) return (lengthM - lapM).clamp(0.0, lengthM);
    final s = route.wrap(trueS[i]);
    return d == FollowDirection.forward ? lengthM - s : s;
  }

  /// The finish is reached within the finish radius (plus the allowance)
  /// along the route or as the crow flies (a route winding near its end).
  bool finishAllowed(int i) {
    if (route.isLoop) {
      return truth(i).lapM >= followFinishMinShare * lengthM - finishSlackM;
    }
    final end = route.pointAt(
      truth(i).d == FollowDirection.forward ? lengthM : 0,
    );
    return math.min(trueRemaining(i), dist(route.pointAt(trueS[i]), end)) <=
        followFinishRadiusM + finishSlackM;
  }

  var t = FollowTracker.start(route.track);
  for (var i = 0; i < measured.length; i++) {
    final m = measured[i];
    t = t.next(at(m.n, m.e));
    if (i == flipAt) {
      if (t.direction != _opposite(c.expected)) {
        failed.add(Metric.directionBeforeFlip);
      }
      // The rider flips only when the direction shown is wrong (undecided:
      // the flip forces reverse).
      if (t.direction != c.expected) {
        t = t.flip();
        flippedAt = i;
      }
    }
    final p = t.progress;
    if (p == null) continue;
    if (p.hasJoined) joinAt ??= i;
    if (joinAt == null) continue;
    ridden.add(trueS[i]);
    final decided = t.direction != FollowDirection.undecided;
    final remaining = trueRemaining(i);
    if (trace) {
      log?.call(
        'fix $i: true s ${trueS[i].toStringAsFixed(1)}, '
        '${t.direction.name}, along ${p.alongM.toStringAsFixed(1)}, '
        'to go ${p.remainingM.toStringAsFixed(1)} '
        '(true ${remaining.toStringAsFixed(1)}), '
        'offset ${p.offsetM.toStringAsFixed(1)}'
        '${p.isOffRoute ? ' off' : ''}${p.isFinished ? ' finished' : ''}, '
        'ridden ${_intervals(t.riddenIntervals)}',
      );
    }
    void fail(Metric metric) {
      if (!failed.add(metric) || trace) return;
      log?.call(
        '${metric.name} at fix $i: true s ${trueS[i].toStringAsFixed(1)}, '
        '${t.direction.name}, to go ${p.remainingM.toStringAsFixed(1)} '
        '(true ${remaining.toStringAsFixed(1)}), '
        'ridden ${_intervals(t.riddenIntervals)}',
      );
    }

    final remainingChecked =
        c.remainingBeforeFlip || flipAt == null || i >= flipAt;
    // "Finished" shows instead of "to go"; whether it came too early is
    // [Metric.earlyFinish] (the finish radius is physical, so it may come
    // with more than the slack left along a winding or doubled-back route).
    if (decided &&
        remainingChecked &&
        !p.isFinished &&
        (p.remainingM - remaining).abs() > remainingSlackM) {
      fail(Metric.remaining);
    }
    // While undecided the UI shows the route's total length, not "finished".
    if (decided && p.isFinished && !finishAllowed(i)) {
      fail(Metric.earlyFinish);
    }
    if (checkRidden && !ridden.covers(t.riddenIntervals)) {
      fail(Metric.ridden);
    }
  }
  final directionOk = route.isSameRoad
      ? t.direction != FollowDirection.undecided
      : t.direction == c.expected;
  if (!directionOk) failed.add(Metric.direction);
  final last = measured.length - 1;
  final reachesFinish =
      c.endsAtFinish &&
      joinAt != null &&
      (!route.isLoop || truth(last).lapM >= lengthM - finishSlackM);
  if (reachesFinish && !(t.progress?.isFinished ?? false)) {
    failed.add(Metric.finishReached);
  }
  final kept = failed.intersection(c.metrics.toSet());
  log?.call(
    'end: failed ${kept.map((m) => m.name).toList()}, ${t.direction.name}, '
    'to go ${t.progress?.remainingM.toStringAsFixed(1)}, '
    'finished ${t.progress?.isFinished}',
  );
  return kept;
}

String _intervals(List<(double, double)> intervals) => [
  for (final (a, b) in intervals)
    '${a.toStringAsFixed(0)}–${b.toStringAsFixed(0)}',
].join(', ');

/// Deterministic seed for [label] (32-bit FNV-1a).
int seedOf(String label) {
  var h = 0x811c9dc5;
  for (final c in label.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  return h;
}

/// The metrics one seeded run of [sc] under [noise] fails.
Set<Metric> runOnce(
  Scenario sc,
  NoiseModel noise,
  int seed, {
  void Function(String)? log,
  bool trace = false,
}) {
  final r = math.Random(seed);
  final plan = sc.plan(r);
  final speed = sc.speed.min + (sc.speed.max - sc.speed.min) * r.nextDouble();
  final (:fixes, :flipAt) = generate(sc.route, plan, speed, r);
  final error = noise.start(r);
  final measured = [
    for (final f in fixes)
      () {
        final e = error();
        return (n: f.pos.n + e.n, e: f.pos.e + e.e);
      }(),
  ];
  return evaluate(
    sc,
    [for (final f in fixes) f.s],
    measured,
    flipAt,
    log: log,
    trace: trace,
  );
}

/// Failure counts of [runs] seeded runs of a scenario under a noise model.
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

/// The seed of run [k] of [sc] under [noise].
int runSeed(Scenario sc, NoiseModel noise, int k) =>
    seedOf('${sc.id}|${noise.name}|$k');

ScenarioResult runScenario(Scenario sc, NoiseModel noise) {
  final result = ScenarioResult(noise.runs);
  for (var k = 0; k < noise.runs; k++) {
    final seed = runSeed(sc, noise, k);
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
