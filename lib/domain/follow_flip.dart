part of 'follow_tracker.dart';

/// The manual flip (Spec 18 §4, #55).
extension FollowFlip on FollowTracker {
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

  RouteHit _nearestTo(List<RouteHit> hits, double alongM) {
    var best = hits.first;
    for (final h in hits) {
      if ((h.alongM - alongM).abs() < (best.alongM - alongM).abs()) best = h;
    }
    return best;
  }
}
