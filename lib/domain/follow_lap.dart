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
  /// the whole route. Parts ridden twice (a jump back onto ridden road, a lap
  /// after a shortcut) are merged and the riding order stays, so a stretch is
  /// drawn once (#57).
  List<(double, double)> get riddenIntervals {
    final r = range;
    if (r == null) return const [];
    return _merged([
      for (final ridden in [..._closed, r])
        if (ridden.hiM > ridden.loM) ..._onLap(ridden),
    ]);
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

/// Parts this close (float noise from the metre sums) count as touching.
const double _touchToleranceM = 1e-6;

/// [parts] with overlapping or touching parts joined. A joined part keeps the
/// place of the first part it absorbed, so the riding order stays.
List<(double, double)> _merged(List<(double, double)> parts) {
  final merged = <(double, double)>[];
  for (var part in parts) {
    var at = merged.length;
    for (var i = merged.length - 1; i >= 0; i--) {
      final other = merged[i];
      if (part.$1 <= other.$2 + _touchToleranceM &&
          other.$1 <= part.$2 + _touchToleranceM) {
        part = (
          part.$1 < other.$1 ? part.$1 : other.$1,
          part.$2 > other.$2 ? part.$2 : other.$2,
        );
        merged.removeAt(i);
        at = i;
      }
    }
    merged.insert(at, part);
  }
  return merged;
}
