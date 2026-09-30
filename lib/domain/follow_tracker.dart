import 'distance_calculator.dart';
import 'follow_direction.dart';
import 'heading.dart' show LatLng;
import 'route_progress.dart';

/// A progress change beyond the distance moved plus this is a jump to another
/// pass of the route, not movement.
const double _jumpSlackM = 2 * followOffRouteThresholdM;

/// A ridden range no longer than this is still just the join point.
const double _joinPointM = 1;

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
    required this._reversed,
    required this._distance,
    this.direction = FollowDirection.undecided,
    this.progress,
    this.range,
    this.lastPoint,
    this._reverseProgress,
    double forwardJoinM = 0,
    double reverseJoinM = 0,
  }) : _fwdJoinM = forwardJoinM,
       _revJoinM = reverseJoinM;

  factory FollowTracker.start(
    RouteTrack track, {
    DistanceCalculator distance = const HaversineDistanceCalculator(),
  }) => FollowTracker._(
    track: track,
    reversed: track.reversed(),
    distance: distance,
  );

  final RouteTrack track;
  final RouteTrack _reversed;
  final DistanceCalculator _distance;
  final FollowDirection direction;

  /// Progress on [orientedTrack]; forward progress while undecided.
  final RouteProgress? progress;

  /// The ridden stretch in original-route metres, from the join on.
  final RiddenRange? range;

  /// The last position fed to [next].
  final LatLng? lastPoint;

  /// While undecided: progress on the reversed route and both along values
  /// at the join.
  final RouteProgress? _reverseProgress;
  final double _fwdJoinM, _revJoinM;

  RouteTrack get orientedTrack => _trackFor(direction);
  bool get hasJoined => progress?.hasJoined ?? false;

  FollowTracker next(LatLng p) {
    if (direction != FollowDirection.undecided) return _nextDecided(p);
    if (hasJoined) return _nextUndecided(p);
    final fwd = track.locate(p, previous: progress);
    if (fwd == null || !fwd.hasJoined) {
      return _with(progress: fwd, lastPoint: p);
    }
    final rev = _reversed.locate(p, previous: mirrored(fwd, track.lengthM));
    final joined = _with(
      progress: fwd,
      reverseProgress: rev,
      forwardJoinM: fwd.alongM,
      reverseJoinM: rev!.alongM,
      range: RiddenRange.at(fwd.alongM),
      lastPoint: p,
    );
    return joined._decide(directionAtJoin(track, p, distance: _distance));
  }

  FollowTracker _nextUndecided(LatLng p) {
    final fwd = track.locate(p, previous: progress)!;
    final rev = _reversed.locate(p, previous: _reverseProgress)!;
    final moved = _movedM(p);
    final fwdDelta = fwd.alongM - progress!.alongM;
    final revDelta = rev.alongM - _reverseProgress!.alongM;
    final fwdJumped = _isJump(fwdDelta, moved);
    final revJumped = _isJump(revDelta, moved);
    final range = _grown(
      _grown(this.range!, fwd, fwd.alongM, jumped: fwdJumped),
      rev,
      track.lengthM - rev.alongM,
      jumped: revJumped,
    );
    // A jump is re-based into the join value, so it adds no advance.
    final fwdJoinM = fwdJumped ? _fwdJoinM + fwdDelta : _fwdJoinM;
    final revJoinM = revJumped ? _revJoinM + revDelta : _revJoinM;
    final next = _with(
      progress: fwd,
      reverseProgress: rev,
      range: range,
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
    final next = orientedTrack.locate(p, previous: progress)!;
    final range = _grown(
      this.range!,
      next,
      direction == FollowDirection.reverse
          ? track.lengthM - next.alongM
          : next.alongM,
      jumped: _isJump(next.alongM - progress!.alongM, _movedM(p)),
    );
    return _with(progress: next, range: range, lastPoint: p);
  }

  double _movedM(LatLng p) {
    final last = lastPoint!;
    return _distance.distanceBetween(last.lat, last.lng, p.lat, p.lng);
  }

  /// [range] after a fix at [at] ([originalM] in original-route metres). It
  /// grows only from on-route movement. After a [jumped] fix (another pass of
  /// the route) a range that is still just the join point moves there, as the
  /// join was ambiguous between passes (a loop's start and finish); a ridden
  /// range is kept.
  static RiddenRange _grown(
    RiddenRange range,
    RouteProgress at,
    double originalM, {
    required bool jumped,
  }) {
    if (jumped) {
      return range.hiM - range.loM <= _joinPointM
          ? RiddenRange.at(originalM)
          : range;
    }
    return at.isOffRoute ? range : range.extend(originalM);
  }

  static bool _isJump(double deltaM, double movedM) =>
      deltaM.abs() > movedM + _jumpSlackM;

  RouteTrack _trackFor(FollowDirection d) =>
      d == FollowDirection.reverse ? _reversed : track;

  /// Applies [decided] (undecided keeps tracking both directions).
  FollowTracker _decide(FollowDirection decided) {
    if (decided == FollowDirection.undecided) return this;
    return _oriented(
      decided,
      decided == FollowDirection.reverse ? _reverseProgress : progress,
    );
  }

  /// Riding [d] at [p]; the undecided bookkeeping is dropped.
  FollowTracker _oriented(FollowDirection d, RouteProgress? p) =>
      FollowTracker._(
        track: track,
        reversed: _reversed,
        distance: _distance,
        direction: d,
        progress: p,
        range: range,
        lastPoint: lastPoint,
      );

  /// Rides the route the other way from [lastPoint], keeping [range]. Only
  /// once joined; while undecided it forces reverse.
  FollowTracker flip() {
    final current = progress;
    if (current == null || !current.hasJoined) return this;
    final flipped = direction == FollowDirection.reverse
        ? FollowDirection.forward
        : FollowDirection.reverse;
    return _oriented(
      flipped,
      _trackFor(flipped).locate(
        lastPoint!,
        previous: mirrored(current, track.lengthM),
      ),
    );
  }

  FollowTracker _with({
    RouteProgress? progress,
    RouteProgress? reverseProgress,
    RiddenRange? range,
    double? forwardJoinM,
    double? reverseJoinM,
    LatLng? lastPoint,
  }) => FollowTracker._(
    track: track,
    reversed: _reversed,
    distance: _distance,
    direction: direction,
    progress: progress,
    range: range ?? this.range,
    lastPoint: lastPoint ?? this.lastPoint,
    reverseProgress: reverseProgress ?? _reverseProgress,
    forwardJoinM: forwardJoinM ?? _fwdJoinM,
    reverseJoinM: reverseJoinM ?? _revJoinM,
  );
}
