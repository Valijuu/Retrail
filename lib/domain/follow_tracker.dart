import 'dart:math' as math;

import 'package:meta/meta.dart' show visibleForTesting;

import 'distance_calculator.dart';
import 'follow_direction.dart';
import 'follow_join.dart';
import 'heading.dart' show LatLng;
import 'route_progress.dart';

/// A progress change beyond the distance moved plus this is a jump to another
/// pass of the route, not movement.
const double _jumpSlackM = 2 * followOffRouteThresholdM;

/// Once decided, progress is first looked for no farther ahead than the
/// rider moved plus this, so a later pass of the road nearby (a hairpin, an
/// out-and-back's other leg) can't capture it.
const double _aheadSlackM = followOffRouteThresholdM;

/// Once decided, progress advances per fix at most this much more than the
/// rider moved.
const double _catchUpM = 2;

/// A fix-to-fix move longer than this beyond the pace is a gap between
/// fixes, not GPS scatter.
const double _scatterM = 25;

/// The share of the rest it catches up per fix beyond that.
const double _catchUpShare = 0.25;

/// Once decided, hits this far behind progress still count: a rider whose
/// progress ran ahead with the GPS error is found on their own pass.
const double _behindM = followOffRouteThresholdM;

/// A flip is a correction when the rider is found on the flipped route no
/// more than this farther off it than before (#55).
const double _correctionSlackM = followOffRouteThresholdM / 2;

/// Metres off the route one metre of the rider's heading against a pass
/// weighs.
const double _headingWeight = 1;

/// Fixes back the rider's heading is measured over.
const int _headingFixes = 3;

/// Metres per degree of latitude (mean Earth radius).
const double _metresPerDegree = 6371000 * math.pi / 180;

/// Metres off the route one metre of misfit along it weighs.
const double _fitWeight = 0.5;

/// Metres off the route one metre behind progress (beyond the tolerance)
/// weighs.
const double _behindWeight = 0.5;

/// How far a GPS fix may fall behind progress without counting against it.
const double _behindToleranceM = 5;

/// Follows a reference route in either direction (Spec 18).
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
  /// until a [flip] starts a fresh lap.
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

  /// Progress at [p] once decided, never going back. On route: the hit
  /// closest to the route and to where the rider would be had they gone on
  /// from the progress point as far as they now are from it, no farther
  /// ahead than that; else Spec 17's look-ahead and full search.
  RouteProgress _locateDecided(LatLng p) {
    final route = _trackFor(direction);
    final previous = _progress!;
    if (!previous.isOffRoute) {
      final fromM = previous.alongM;
      // How far on the rider is from the progress point, even while progress
      // holds there over several fixes.
      final onM = _distanceTo(p, route.pointAt(fromM));
      final hits = route.hitsWithin(
        p,
        fromM - _behindM,
        fromM + onM + _aheadSlackM,
      );
      if (hits.isNotEmpty) {
        final hit = _likeliest(route, hits, fromM, onM, p);
        // A hit behind progress (the GPS error) holds it where it is, and
        // progress advances no more than the rider moved (plus a little), so
        // a fix thrown across a corner or a hairpin is caught up with over a
        // few fixes rather than at once.
        final maxM = fromM + _paceM(p) + _catchUpM;
        final alongM = hit.alongM > maxM
            ? maxM + _catchUpShare * (hit.alongM - maxM)
            : math.max(hit.alongM, fromM);
        return route.progressAt(p, (alongM: alongM, offsetM: hit.offsetM));
      }
    }
    return route.locate(p, previous: previous)!;
  }

  static RouteHit _nearestTo(List<RouteHit> hits, double alongM) {
    var best = hits.first;
    for (final h in hits) {
      if ((h.alongM - alongM).abs() < (best.alongM - alongM).abs()) best = h;
    }
    return best;
  }

  /// The hit of [hits] that best fits a rider at [p], [onM] from the
  /// progress point at [fromM]: close to the route, about as far along it
  /// from there as the rider is from it (not a pass of the same road coming
  /// back), not far behind progress (beyond the GPS error,
  /// [_behindToleranceM]), and on a pass running the way the rider heads.
  RouteHit _likeliest(
    RouteTrack route,
    List<RouteHit> hits,
    double fromM,
    double onM,
    LatLng p,
  ) {
    if (hits.length == 1) return hits.single;
    final from = _recent.isEmpty ? lastPoint! : _recent.first;
    double cost(RouteHit h) {
      final alongM = h.alongM - fromM;
      final behindM = -alongM - _behindToleranceM;
      final headingM = _alongRouteM(route, h.alongM, from, p);
      return h.offsetM +
          _fitWeight * (alongM.abs() - onM).abs() +
          _behindWeight * (behindM > 0 ? behindM : 0) +
          _headingWeight * (headingM < 0 ? -headingM : 0);
    }

    var best = hits.first;
    for (final h in hits) {
      if (cost(h) < cost(best)) best = h;
    }
    return best;
  }

  /// How far the move from [a] to [b] runs along [route] at [alongM], in
  /// metres (negative: against it). Local flat-earth approximation.
  static double _alongRouteM(
    RouteTrack route,
    double alongM,
    LatLng a,
    LatLng b,
  ) {
    final t = routeHeading(route, alongM);
    final dx = (b.lng - a.lng) * math.cos(a.lat * math.pi / 180);
    final dy = b.lat - a.lat;
    return (dx * t.x + dy * t.y) * _metresPerDegree;
  }

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

  /// [alongM] seen from the other end of the tracked routes: the same point
  /// on the route of the other direction.
  double _mirroredM(double alongM) => _forward.lengthM - alongM;

  /// Rides the route the other way from [lastPoint]. Only once joined; while
  /// undecided it forces reverse from the join.
  ///
  /// Once decided, a flip either corrects a wrong direction or follows a
  /// U-turn, told apart by where the rider is on the flipped route (#55): a
  /// rider found as far ahead of the mirrored join as they have ridden went
  /// that way all along (a lollipop's stem is the same road both ways), so the
  /// join stays the lap anchor and the ridden part is re-measured from it.
  /// Otherwise the rider turned: on a loop a fresh lap starts from the turn
  /// and the ridden part is kept.
  FollowTracker flip() {
    final current = _progress;
    if (current == null || !current.hasJoined) return this;
    if (direction == FollowDirection.undecided) return _flipUndecided(current);
    final flipped = direction == FollowDirection.reverse
        ? FollowDirection.forward
        : FollowDirection.reverse;
    final target = _trackFor(flipped);
    final lapBackM = isLoop && _mirroredM(_joinM) > _lapM ? _lapM : 0.0;
    final joinM = _mirroredM(_joinM) - lapBackM;
    final ridM = current.alongM - _joinM;
    final corrected = current.isOffRoute
        ? null
        : _correctionHit(target, joinM, ridM, current.offsetM);
    if (corrected != null) {
      return _oriented(
        flipped,
        target.progressAt(lastPoint!, corrected),
        joinM: joinM,
        lapFinished: false,
        ridden: RiddenRange.at(
          _originalM(flipped, joinM),
        ).extend(_originalM(flipped, corrected.alongM)),
      );
    }
    final mirroredM = _mirroredM(current.alongM);
    final baseM = isLoop && mirroredM > _lapM ? mirroredM - _lapM : mirroredM;
    // Progress may have run ahead of the rider, who turned: the fresh lap
    // starts where the rider is.
    final turn = current.isOffRoute
        ? null
        : RouteTrack.closestOf(
            target.hitsWithin(
              lastPoint!,
              baseM - followOffRouteThresholdM,
              baseM + followOffRouteThresholdM,
            ),
          );
    final p = turn == null
        ? _mirroredProgress(target, current, baseM)
        : target.progressAt(lastPoint!, turn);
    final kept = range!;
    // On a loop the flipped along may lie a lap away from the current one:
    // the kept range moves with it so it stays over the same ground.
    final shiftM = isLoop
        ? _originalM(flipped, baseM) - _originalM(direction, current.alongM)
        : 0.0;
    return _oriented(
      flipped,
      p,
      joinM: p.alongM,
      lapFinished: false,
      ridden: RiddenRange(kept.loM + shiftM, kept.hiM + shiftM),
    );
  }

  /// The rider's hit on [target] ahead of the join at [joinM] by about
  /// [ridM] (nearer that than the join), on the road the rider is on
  /// ([offsetM] off it, give or take [_correctionSlackM]); null when the
  /// rider isn't there.
  RouteHit? _correctionHit(
    RouteTrack target,
    double joinM,
    double ridM,
    double offsetM,
  ) {
    final hits = [
      for (final h in target.hitsWithin(
        lastPoint!,
        joinM + ridM / 2,
        joinM + ridM + followJoinWindowM,
      ))
        if (h.offsetM <= offsetM + _correctionSlackM) h,
    ];
    return hits.isEmpty ? null : _nearestTo(hits, joinM + ridM);
  }

  /// Undecided → reverse from the join, with what was ridden since.
  FollowTracker _flipUndecided(RouteProgress current) {
    final lapBackM = isLoop && _mirroredM(_joinM) > _lapM ? _lapM : 0.0;
    final joinM = _mirroredM(_joinM) - lapBackM;
    final p = _mirroredProgress(
      _reversed,
      current,
      _mirroredM(current.alongM) - lapBackM,
    );
    return _oriented(
      FollowDirection.reverse,
      p,
      joinM: joinM,
      ridden: RiddenRange.at(
        _originalM(FollowDirection.reverse, joinM),
      ).extend(_originalM(FollowDirection.reverse, p.alongM)),
    );
  }

  /// [current] seen at [alongM] on [target], the other direction's route.
  RouteProgress _mirroredProgress(
    RouteTrack target,
    RouteProgress current,
    double alongM,
  ) {
    if (!current.isOffRoute) {
      return target.progressAt(lastPoint!, (
        alongM: alongM,
        offsetM: current.offsetM,
      ));
    }
    return RouteProgress(
      alongM: alongM,
      remainingM: target.lengthM - alongM,
      offsetM: current.offsetM,
      isOffRoute: true,
      isFinished: false,
      hasJoined: true,
    );
  }

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
