import 'dart:math' as math;

import 'distance_calculator.dart';
import 'follow_direction.dart';
import 'heading.dart' show LatLng;
import 'route_progress.dart';

/// A progress change beyond the distance moved plus this is a jump to another
/// pass of the route, not movement.
const double _jumpSlackM = 2 * followOffRouteThresholdM;

/// [p] seen from the other end of a route of length [lengthM]: joined and on
/// route, at the same physical point.
RouteProgress mirrored(RouteProgress p, double lengthM) => RouteProgress(
  alongM: lengthM - p.alongM,
  remainingM: p.alongM,
  offsetM: p.offsetM,
  isOffRoute: false,
  isFinished: false,
  hasJoined: true,
);

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
    this._reverseProgress,
    this._forwardRange,
    this._reverseRange,
    double forwardJoinM = 0,
    double reverseJoinM = 0,
  }) : _fwdJoinM = forwardJoinM,
       _revJoinM = reverseJoinM;

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
  final RiddenRange? range;

  /// The last position fed to [next].
  final LatLng? lastPoint;

  /// Both along values at the join (moved by pass jumps while undecided).
  final double _fwdJoinM, _revJoinM;

  /// While undecided: progress on the reversed route and what each tracker
  /// has ridden (original-route metres, as [range]).
  final RouteProgress? _reverseProgress;
  final RiddenRange? _forwardRange, _reverseRange;

  RouteTrack get orientedTrack =>
      direction == FollowDirection.reverse ? _reversedLap : track;
  bool get hasJoined => _progress?.hasJoined ?? false;

  /// Progress on [orientedTrack]; forward progress while undecided. On a loop
  /// it runs one lap from the join: along continues past the start/finish,
  /// the finish is back at the join.
  RouteProgress? get progress {
    final p = _progress;
    if (p == null || !isLoop) return p;
    final joinM = _joinM;
    final joinPoint = _trackFor(direction).pointAt(joinM);
    final toJoin = _distance.distanceBetween(
      lastPoint!.lat,
      lastPoint!.lng,
      joinPoint.lat,
      joinPoint.lng,
    );
    return RouteProgress(
      alongM: p.alongM,
      remainingM: math.max(0, joinM + track.lengthM - p.alongM),
      offsetM: p.offsetM,
      isOffRoute: p.isOffRoute,
      isFinished:
          !p.isOffRoute &&
          p.alongM - joinM >= followFinishMinShare * track.lengthM &&
          toJoin <= followFinishRadiusM,
      hasJoined: p.hasJoined,
    );
  }

  /// True when [track] is a loop; it is then tracked laid out twice.
  bool get isLoop => !identical(_forward, track);

  /// The along value at the join on the tracked route of [direction].
  double get _joinM =>
      direction == FollowDirection.reverse ? _revJoinM : _fwdJoinM;

  /// The ridden parts of [track], in its metres; empty until decided. On a
  /// loop a part crossing the start/finish is split in two, and a full lap is
  /// the whole route.
  List<(double, double)> get riddenIntervals {
    final r = range;
    if (r == null) return const [];
    if (!isLoop) return [(r.loM, r.hiM)];
    final lapM = track.lengthM;
    if (r.hiM - r.loM >= lapM) return [(0, lapM)];
    final lo = r.loM % lapM, hi = lo + r.hiM - r.loM;
    return hi <= lapM ? [(lo, hi)] : [(lo, lapM), (0, hi - lapM)];
  }

  FollowTracker next(LatLng p) {
    if (direction != FollowDirection.undecided) return _nextDecided(p);
    if (hasJoined) return _nextUndecided(p);
    final fwd = _forward.locate(p, previous: _progress);
    if (fwd == null || !fwd.hasJoined) {
      return _with(progress: fwd, lastPoint: p);
    }
    final rev = _reversed.locate(p, previous: _mirroredOnto(_reversed, fwd));
    final joined = _with(
      progress: fwd,
      reverseProgress: rev,
      forwardJoinM: fwd.alongM,
      reverseJoinM: rev!.alongM,
      forwardRange: RiddenRange.at(fwd.alongM),
      reverseRange: RiddenRange.at(_forward.lengthM - rev.alongM),
      lastPoint: p,
    );
    return joined._decide(directionAtJoin(track, p, distance: _distance));
  }

  FollowTracker _nextUndecided(LatLng p) {
    final fwd = _forward.locate(p, previous: _progress)!;
    final rev = _reversed.locate(p, previous: _reverseProgress)!;
    final moved = _movedM(p);
    final fwdDelta = fwd.alongM - _progress!.alongM;
    final revDelta = rev.alongM - _reverseProgress!.alongM;
    final fwdJumped = _isJump(fwdDelta, moved);
    final revJumped = _isJump(revDelta, moved);
    // A jump re-anchors that tracker's range: it is now on another pass.
    final fwdRange = fwdJumped
        ? RiddenRange.at(fwd.alongM)
        : _grown(_forwardRange!, fwd, fwd.alongM);
    final revOriginalM = _forward.lengthM - rev.alongM;
    final revRange = revJumped
        ? RiddenRange.at(revOriginalM)
        : _grown(_reverseRange!, rev, revOriginalM);
    // A jump is re-based into the join value, so it adds no advance.
    final fwdJoinM = fwdJumped ? _fwdJoinM + fwdDelta : _fwdJoinM;
    final revJoinM = revJumped ? _revJoinM + revDelta : _revJoinM;
    final next = _with(
      progress: fwd,
      reverseProgress: rev,
      forwardRange: fwdRange,
      reverseRange: revRange,
      forwardJoinM: fwdJoinM,
      reverseJoinM: revJoinM,
      lastPoint: p,
    );
    return next._decide(
      decideDirection(
        forwardAdvanceM: fwd.alongM - fwdJoinM,
        reverseAdvanceM: rev.alongM - revJoinM,
      ),
    );
  }

  FollowTracker _nextDecided(LatLng p) {
    final next = _trackFor(direction).locate(p, previous: _progress)!;
    final delta = next.alongM - _progress!.alongM;
    if (_isJump(delta, _movedM(p))) {
      // A jump to another pass extends nothing and is re-based into the join,
      // so it doesn't count towards a loop's lap.
      final isReverse = direction == FollowDirection.reverse;
      return _with(
        progress: next,
        lastPoint: p,
        forwardJoinM: isReverse ? null : _fwdJoinM + delta,
        reverseJoinM: isReverse ? _revJoinM + delta : null,
      );
    }
    final range = _grown(
      this.range!,
      next,
      direction == FollowDirection.reverse
          ? _forward.lengthM - next.alongM
          : next.alongM,
    );
    return _with(progress: next, range: range, lastPoint: p);
  }

  /// [p] seen on [target], the other direction's track. On a loop it lands
  /// in [target]'s first lap, so a whole lap lies ahead.
  RouteProgress _mirroredOnto(RouteTrack target, RouteProgress p) {
    final m = mirrored(p, _forward.lengthM);
    if (!isLoop) return m;
    final lapM = target.cumulativeM[track.points.length - 1];
    return m.alongM <= lapM ? m : mirrored(p, _forward.lengthM - lapM);
  }

  double _movedM(LatLng p) {
    final last = lastPoint!;
    return _distance.distanceBetween(last.lat, last.lng, p.lat, p.lng);
  }

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

  /// Applies [decided] (undecided keeps tracking both directions).
  FollowTracker _decide(FollowDirection decided) {
    if (decided == FollowDirection.undecided) return this;
    return _oriented(
      decided,
      decided == FollowDirection.reverse ? _reverseProgress : _progress,
    );
  }

  /// Riding [d] at [p]; the undecided bookkeeping is dropped. Leaving
  /// undecided, the range is the ridden range of [d]'s tracker. [joinM]
  /// replaces [d]'s join along.
  FollowTracker _oriented(
    FollowDirection d,
    RouteProgress? p, {
    double? joinM,
  }) => FollowTracker._(
    track: track,
    forward: _forward,
    reversed: _reversed,
    reversedLap: _reversedLap,
    distance: _distance,
    direction: d,
    progress: p,
    range: direction != FollowDirection.undecided
        ? range
        : d == FollowDirection.reverse
        ? _reverseRange
        : _forwardRange,
    lastPoint: lastPoint,
    forwardJoinM: d == FollowDirection.forward ? joinM ?? _fwdJoinM : _fwdJoinM,
    reverseJoinM: d == FollowDirection.reverse ? joinM ?? _revJoinM : _revJoinM,
  );

  /// Rides the route the other way from [lastPoint], keeping [range]. Only
  /// once joined; while undecided it forces reverse with what the reverse
  /// tracker rode.
  FollowTracker flip() {
    final current = _progress;
    if (current == null || !current.hasJoined) return this;
    final flipped = direction == FollowDirection.reverse
        ? FollowDirection.forward
        : FollowDirection.reverse;
    final target = _trackFor(flipped);
    final p = target.locate(
      lastPoint!,
      previous: _mirroredOnto(target, current),
    );
    // On a loop the flip starts a fresh lap from where the rider turned.
    return _oriented(flipped, p, joinM: p?.alongM);
  }

  FollowTracker _with({
    RouteProgress? progress,
    RouteProgress? reverseProgress,
    RiddenRange? range,
    double? forwardJoinM,
    double? reverseJoinM,
    RiddenRange? forwardRange,
    RiddenRange? reverseRange,
    LatLng? lastPoint,
  }) => FollowTracker._(
    track: track,
    forward: _forward,
    reversed: _reversed,
    reversedLap: _reversedLap,
    distance: _distance,
    direction: direction,
    progress: progress,
    range: range ?? this.range,
    lastPoint: lastPoint ?? this.lastPoint,
    reverseProgress: reverseProgress ?? _reverseProgress,
    forwardJoinM: forwardJoinM ?? _fwdJoinM,
    reverseJoinM: reverseJoinM ?? _revJoinM,
    forwardRange: forwardRange ?? _forwardRange,
    reverseRange: reverseRange ?? _reverseRange,
  );
}
