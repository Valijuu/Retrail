part of 'follow_tracker.dart';

/// What a rider has done of the route (Spec 18 §6, Loops): the progress
/// shown, one lap from the join on a loop, and the ridden parts.
extension FollowLap on FollowTracker {
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

  /// The ridden parts of [track], in its metres; empty until decided. A
  /// part not ridden yet (a single point, as after a jump) is left out. On a
  /// loop a part crossing the start/finish is split in two, and a full lap is
  /// the whole route.
  List<(double, double)> get riddenIntervals {
    final r = range;
    if (r == null) return const [];
    return [
      for (final ridden in [..._closed, r])
        if (ridden.hiM > ridden.loM) ..._onLap(ridden),
    ];
  }

  /// [r] on one lap of [track]: split at the start/finish on a loop.
  List<(double, double)> _onLap(RiddenRange r) {
    if (!isLoop) return [(r.loM, r.hiM)];
    if (r.hiM - r.loM >= _lapM) return [(0, _lapM)];
    final lo = r.loM % _lapM, hi = lo + r.hiM - r.loM;
    return hi <= _lapM ? [(lo, hi)] : [(lo, _lapM), (0, hi - _lapM)];
  }
}

/// [range] grown by a fix at [at] ([originalM] in original-route metres)
/// when it is on route.
RiddenRange _grown(RiddenRange range, RouteProgress at, double originalM) =>
    at.isOffRoute ? range : range.extend(originalM);
