import 'dart:math' as math;

import 'package:meta/meta.dart' show visibleForTesting;

import 'distance_calculator.dart';
import 'follow_direction.dart';
import 'follow_join.dart';
import 'follow_progress.dart';
import 'heading.dart' show LatLng;
import 'route_progress.dart';

part 'follow_flip.dart';

/// A progress change beyond the distance moved plus this is a jump to another
/// pass of the route, not movement.
const double _jumpSlackM = 2 * followOffRouteThresholdM;

/// A fix-to-fix move longer than this beyond the pace is a gap between
/// fixes, not GPS scatter.
const double _scatterM = 25;

/// A flip is a correction when the rider is found on the flipped route no
/// more than this farther off it than before (#55).
const double _correctionSlackM = followOffRouteThresholdM / 2;

/// Fixes back the rider's heading is measured over.
const int _headingFixes = 3;

/// Follows a reference route in either direction (Spec 18): undecided from
/// the join until the rider has moved [followDirectionDecisionM] along it one
/// way ([FollowJoin]), then progress on the route of that direction
/// ([decidedProgress]); [flip] turns it by hand.
class FollowTracker {
  const FollowTracker._({
    required this.track,
    required this._forward,
    required this._reversed,
    required this._reversedLap,
    required this._distance,
    this.direction = FollowDirection.undecided,
    this._progress,
    this.range,
    this.lastPoint,
    this._join,
    this._joinM = 0,
    this._lapFinished = false,
    this._recent = const [],
  });

  factory FollowTracker.start(
    RouteTrack track, {
    DistanceCalculator distance = const HaversineDistanceCalculator(),
  }) {
    final reversedLap = track.reversed();
    final forward = track.isLoop ? track.doubled() : track;
    return FollowTracker._(
      track: track,
      forward: forward,
      reversed: track.isLoop ? forward.reversed() : reversedLap,
      reversedLap: reversedLap,
      distance: distance,
    );
  }

  final RouteTrack track;

  /// The routes tracked each way: [track] and its reversed copy, laid out
  /// twice on a loop so crossing the start/finish continues on the second lap.
  final RouteTrack _forward, _reversed;

  /// [track] reversed, one lap.
  final RouteTrack _reversedLap;
  final DistanceCalculator _distance;
  final FollowDirection direction;

  /// Progress on the tracked route; forward while undecided.
  final RouteProgress? _progress;

  /// The ridden stretch in original-route metres (on a loop, of the route laid
  /// out twice), from the join on; null until the direction is decided.
  /// Consumers read [riddenIntervals].
  @visibleForTesting
  final RiddenRange? range;

  /// The last position fed to [next].
  final LatLng? lastPoint;

  /// The positions fed before [lastPoint], oldest first: which way the rider
  /// is heading.
  final List<LatLng> _recent;

  /// While undecided: the join the direction is measured from; null before
  /// the join and while off route since.
  final FollowJoin? _join;

  /// The along value at the join on the tracked route of [direction] (moved
  /// by pass jumps once decided).
  final double _joinM;

  /// On a loop: the lap from the join has been finished. It stays finished
  /// until a [flip].
  final bool _lapFinished;

  RouteTrack get orientedTrack =>
      direction == FollowDirection.reverse ? _reversedLap : track;
  bool get hasJoined => _progress?.hasJoined ?? false;

  /// Progress on [orientedTrack]; forward progress while undecided. On a loop
  /// it runs one lap from the join: along continues past the start/finish,
  /// the finish is back at the join, and remaining is at most one lap.
  RouteProgress? get progress {
    final p = _progress;
    if (p == null || !isLoop) return p;
    final joinPoint = _trackFor(direction).pointAt(_joinM);
    final toJoin = _distance.distanceBetween(
      lastPoint!.lat,
      lastPoint!.lng,
      joinPoint.lat,
      joinPoint.lng,
    );
    return RouteProgress(
      alongM: p.alongM,
      remainingM: _lapFinished
          ? 0
          : (_joinM + _lapM - p.alongM).clamp(0.0, _lapM),
      offsetM: p.offsetM,
      isOffRoute: p.isOffRoute,
      isFinished:
          _lapFinished ||
          !p.isOffRoute &&
              p.alongM - _joinM >= followFinishMinShare * _lapM &&
              toJoin <= followFinishRadiusM,
      hasJoined: p.hasJoined,
    );
  }

  /// True when [track] is a loop; it is then tracked laid out twice.
  bool get isLoop => !identical(_forward, track);

  double get _lapM => track.lengthM;

  /// The ridden parts of [track], in its metres; empty until decided. On a
  /// loop a part crossing the start/finish is split in two, and a full lap is
  /// the whole route.
  List<(double, double)> get riddenIntervals {
    final r = range;
    if (r == null) return const [];
    if (!isLoop) return [(r.loM, r.hiM)];
    if (r.hiM - r.loM >= _lapM) return [(0, _lapM)];
    final lo = r.loM % _lapM, hi = lo + r.hiM - r.loM;
    return hi <= _lapM ? [(lo, hi)] : [(lo, _lapM), (0, hi - _lapM)];
  }

  FollowTracker next(LatLng p) {
    final t = _step(p);
    final finishesLap =
        t.isLoop && !t._lapFinished && (t.progress?.isFinished ?? false);
    final last = lastPoint;
    return t._with(
      lapFinished: finishesLap ? true : null,
      recent: last == null
          ? const []
          : [..._recent.skip(_recent.length < _headingFixes ? 0 : 1), last],
    );
  }

  FollowTracker _step(LatLng p) {
    if (direction != FollowDirection.undecided) return _nextDecided(p);
    if (!hasJoined) {
      final joined = _joinAt(p);
      final join = joined._join;
      if (join == null) return joined;
      final atJoin = directionAtJoin(track, p, distance: _distance);
      if (atJoin == FollowDirection.undecided) return joined;
      final hit = (alongM: join.joinM, offsetM: join.offsetM);
      return joined._decided(atJoin, (
        hit: hit,
        pass: 0,
        anchorM: join.joinM,
        signedM: 0,
        fitM: join.offsetM,
      ));
    }
    final joined = _join;
    // Off route since the join: measure from here on.
    if (joined == null) return _joinAt(p);
    final (:join, :seen) = joined.see(_forward, p, _distance);
    // Off route, or out of the join's window: measure from here on.
    if (seen.isEmpty) return _joinAt(p);
    final fitting = bestFitting(seen);
    final closest = _closest(fitting);
    final next = _with(
      progress: _forward.progressAt(p, closest.hit),
      lastPoint: p,
    );
    final decided = decideDirection(fitting.map((h) => h.signedM));
    if (decided == FollowDirection.undecided) {
      return next._with(join: join.standing(seen));
    }
    return next._decided(decided, _closestGoing(decided, fitting));
  }

  /// Joins (again) at [p]: a fresh window, or off route without one.
  FollowTracker _joinAt(LatLng p) {
    final join = FollowJoin.at(_forward, p, lapM: isLoop ? _lapM : null);
    final progress = join == null
        ? _forward.locate(p, previous: _progress)
        : _forward.progressAt(p, (alongM: join.joinM, offsetM: join.offsetM));
    return FollowTracker._(
      track: track,
      forward: _forward,
      reversed: _reversed,
      reversedLap: _reversedLap,
      distance: _distance,
      progress: progress,
      lastPoint: p,
      join: join,
      joinM: join?.joinM ?? _joinM,
    );
  }

  /// The closest of the hits that lie ahead of their anchor when [d] is
  /// forward, behind it when reverse: where the rider is, on a pass ridden
  /// that way.
  static JoinHit _closestGoing(FollowDirection d, List<JoinHit> seen) {
    final going = [
      for (final h in seen)
        if (d == FollowDirection.forward ? h.signedM >= 0 : h.signedM <= 0) h,
    ];
    return _closest(going);
  }

  static JoinHit _closest(List<JoinHit> seen) {
    var best = seen.first;
    for (final h in seen) {
      if (h.hit.offsetM < best.hit.offsetM) best = h;
    }
    return best;
  }

  /// Riding [d], decided at [at] (forward-route metres) on [lastPoint]: the
  /// join is [at]'s anchor and the ridden range runs from it to [at]. On a
  /// loop both move to the first lap, so a whole lap lies ahead.
  FollowTracker _decided(FollowDirection d, JoinHit at) {
    final isReverse = d == FollowDirection.reverse;
    double oriented(double m) => isReverse ? _forward.lengthM - m : m;
    var joinM = oriented(at.anchorM), alongM = oriented(at.hit.alongM);
    if (isLoop && joinM >= _lapM) {
      joinM -= _lapM;
      alongM -= _lapM;
    }
    final progress = _trackFor(
      d,
    ).progressAt(lastPoint!, (alongM: alongM, offsetM: at.hit.offsetM));
    return _oriented(
      d,
      progress,
      joinM: joinM,
      ridden: RiddenRange.at(
        _originalM(d, joinM),
      ).extend(_originalM(d, alongM)),
    );
  }

  FollowTracker _nextDecided(LatLng p) {
    final next = _locateDecided(p);
    final delta = next.alongM - _progress!.alongM;
    if (_isJump(delta, _movedM(p))) {
      // A jump to another pass extends nothing and is re-based into the join,
      // so it doesn't count towards a loop's lap.
      return _with(progress: next, lastPoint: p, joinM: _joinM + delta);
    }
    final range = _grown(this.range!, next, _originalM(direction, next.alongM));
    return _with(progress: next, range: range, lastPoint: p);
  }

  /// Progress at [p] once decided (see [decidedProgress]).
  RouteProgress _locateDecided(LatLng p) => decidedProgress(
    _trackFor(direction),
    _progress!,
    p,
    headingFrom: _recent.isEmpty ? lastPoint! : _recent.first,
    paceM: _paceM(p),
    distance: _distance,
  );

  /// [alongM] on [d]'s tracked route in original-route metres (as [range]).
  double _originalM(FollowDirection d, double alongM) =>
      d == FollowDirection.reverse ? _forward.lengthM - alongM : alongM;

  double _movedM(LatLng p) => _distanceTo(p, lastPoint!);

  /// How far the rider moved to [p]: on average over the last few fixes (a
  /// single fix-to-fix move is mostly GPS scatter at a slow pace), unless
  /// this move is longer than any scatter (a gap between fixes).
  double _paceM(LatLng p) {
    final movedM = _movedM(p);
    if (_recent.isEmpty) return movedM;
    final averageM = _distanceTo(p, _recent.first) / (_recent.length + 1);
    return math.max(averageM, movedM - _scatterM);
  }

  double _distanceTo(LatLng a, LatLng b) =>
      _distance.distanceBetween(a.lat, a.lng, b.lat, b.lng);

  /// [range] grown by a fix at [at] ([originalM] in original-route metres)
  /// when it is on route.
  static RiddenRange _grown(
    RiddenRange range,
    RouteProgress at,
    double originalM,
  ) => at.isOffRoute ? range : range.extend(originalM);

  static bool _isJump(double deltaM, double movedM) =>
      deltaM.abs() > movedM + _jumpSlackM;

  RouteTrack _trackFor(FollowDirection d) =>
      d == FollowDirection.reverse ? _reversed : _forward;

  /// Riding [d] with progress [p] from the join at [joinM]; the undecided
  /// join is dropped. [ridden] replaces the range, [lapFinished] the latch.
  FollowTracker _oriented(
    FollowDirection d,
    RouteProgress? p, {
    required double joinM,
    RiddenRange? ridden,
    bool? lapFinished,
  }) => FollowTracker._(
    track: track,
    forward: _forward,
    reversed: _reversed,
    reversedLap: _reversedLap,
    distance: _distance,
    direction: d,
    progress: p,
    range: ridden ?? range,
    lastPoint: lastPoint,
    joinM: joinM,
    lapFinished: lapFinished ?? _lapFinished,
  );

  FollowTracker _with({
    RouteProgress? progress,
    RiddenRange? range,
    double? joinM,
    LatLng? lastPoint,
    bool? lapFinished,
    FollowJoin? join,
    List<LatLng>? recent,
  }) => FollowTracker._(
    track: track,
    forward: _forward,
    reversed: _reversed,
    reversedLap: _reversedLap,
    distance: _distance,
    direction: direction,
    progress: progress ?? _progress,
    range: range ?? this.range,
    lastPoint: lastPoint ?? this.lastPoint,
    join: join ?? _join,
    joinM: joinM ?? _joinM,
    lapFinished: lapFinished ?? _lapFinished,
    recent: recent ?? _recent,
  );
}
