import 'dart:math' as math;

import 'distance_calculator.dart';
import 'heading.dart' show LatLng;
import 'route_progress.dart';

/// While the direction is undecided only this far along the route either
/// side of the join is searched: the join's own pass of the route (Spec 18).
const double followJoinWindowM = 2 * followOffRouteThresholdM;

/// Hits within this of the closest one are as good a fit: the same road
/// where the route runs it more than once (an out-and-back's legs, a
/// lollipop's stem), or the legs either side of a corner.
const double followSameRoadBandM = 4;

/// A pass running the opposite way to the closest hit's within this of it
/// is the same road ridden back (GPS-recorded routes trace it a few metres
/// apart each way).
const double followRoadBackBandM = 15;

/// While the rider stays within this of the join, the join settles on the
/// average of their positions (GPS scatter around a rider standing still).
const double followJoinSettleM = 8;

/// Cosine below which two passes run opposite ways.
const double _oppositeCos = -0.7;

/// [hits] on [track] that fit about as well as the closest: within
/// [followSameRoadBandM] of it, or within [followRoadBackBandM] on a pass
/// running the other way. In their order.
List<RouteHit> sameRoad(RouteTrack track, List<RouteHit> hits) {
  if (hits.isEmpty) return const [];
  var closest = hits.first;
  for (final h in hits) {
    if (h.offsetM < closest.offsetM) closest = h;
  }
  final heading = routeHeading(track, closest.alongM);
  bool fits(RouteHit h) {
    if (h.offsetM <= closest.offsetM + followSameRoadBandM) return true;
    if (h.offsetM > closest.offsetM + followRoadBackBandM) return false;
    final other = routeHeading(track, h.alongM);
    return heading.x * other.x + heading.y * other.y < _oppositeCos;
  }

  return [
    for (final h in hits)
      if (fits(h)) h,
  ];
}

/// The unit direction of [track] at [alongM] in a local flat frame (x east,
/// y north); zero on a route without length there.
({double x, double y}) routeHeading(RouteTrack track, double alongM) {
  final a = track.pointAt(alongM - 1), b = track.pointAt(alongM + 1);
  final x = (b.lng - a.lng) * math.cos(a.lat * math.pi / 180);
  final y = b.lat - a.lat;
  final norm = math.sqrt(x * x + y * y);
  return norm == 0 ? (x: 0, y: 0) : (x: x / norm, y: y / norm);
}

/// A hit of the rider seen from the join: [anchorM] is the pass of the join
/// it lies on, [signedM] how far along the route the rider is from the join
/// there (from where the join settled, see [FollowJoin.standing]; at most as
/// far as the rider is from that point), and
/// [fitM] how far off that pass the rider has been on average since the
/// join.
typedef JoinHit = ({
  RouteHit hit,
  int pass,
  double anchorM,
  double signedM,
  double fitM,
});

/// Where an undecided rider joined the route: [joinM] along the forward
/// route (laid out twice on a loop), and the join's hits on each pass of the
/// road through it within the window ([anchorsM]).
class FollowJoin {
  const FollowJoin._(
    this.joinM,
    this.offsetM,
    this.anchorsM,
    this._offsetSumsM,
    this._shiftsM,
    this._settledFixes, [
    this._fixes = 1,
  ]);

  /// Joins [track] at [p], on the closest pass (passes as good a fit: the
  /// first). On a loop of [lapM], a join within the window of the start
  /// moves to the second lap, so the window reaches back across the
  /// start/finish. Null when [p] is off route.
  static FollowJoin? at(RouteTrack track, LatLng p, {double? lapM}) {
    final passes = sameRoad(track, track.passesOf(p));
    if (passes.isEmpty) return null;
    final first = passes.first;
    var joinM = first.alongM;
    if (lapM != null && joinM < followJoinWindowM) joinM += lapM;
    final anchors = sameRoad(track, _window(track, p, joinM));
    final hits = anchors.isEmpty ? [first] : anchors;
    return FollowJoin._(
      joinM,
      first.offsetM,
      [
        if (anchors.isEmpty) joinM else ...[for (final a in anchors) a.alongM],
      ],
      [for (final a in hits) a.offsetM],
      List.filled(hits.length, 0),
      List.filled(hits.length, 1),
    );
  }

  final double joinM;

  /// The rider's distance from the route at the join.
  final double offsetM;
  final List<double> anchorsM;

  /// Per anchor: the rider's distances from its pass summed over [_fixes].
  final List<double> _offsetSumsM;
  final int _fixes;

  /// Per anchor: how far the join has settled along its pass, over how many
  /// fixes.
  final List<double> _shiftsM;
  final List<int> _settledFixes;

  /// The join after the rider was seen at [seen]: on each pass where the
  /// rider is within [followJoinSettleM] of it, moved towards the rider to
  /// the average of the positions so far.
  FollowJoin standing(List<JoinHit> seen) {
    final shifts = [..._shiftsM], settled = [..._settledFixes];
    final closest = <int, JoinHit>{};
    for (final h in seen) {
      final best = closest[h.pass];
      if (best == null || h.hit.offsetM < best.hit.offsetM) closest[h.pass] = h;
    }
    for (final MapEntry(key: k, value: h) in closest.entries) {
      if (h.signedM.abs() >= followJoinSettleM) continue;
      settled[k]++;
      shifts[k] += h.signedM / settled[k];
    }
    return FollowJoin._(
      joinM,
      offsetM,
      anchorsM,
      _offsetSumsM,
      shifts,
      settled,
      _fixes,
    );
  }

  /// [p] seen from the join: its hits within the window that fit about as
  /// well as the closest ([sameRoad]), each on the pass of the join nearest
  /// to it, and the join with [p] counted into each
  /// pass's fit (its closest hit; a pass [p] isn't on counts as off by
  /// [followOffRouteThresholdM]). No hits when [p] is off route there.
  ({FollowJoin join, List<JoinHit> seen}) see(
    RouteTrack track,
    LatLng p,
    DistanceCalculator distance,
  ) {
    // The window spans every pass of the join, the join's window around each.
    final hits = track.hitsWithin(
      p,
      anchorsM.reduce(math.min) - followJoinWindowM,
      anchorsM.reduce(math.max) + followJoinWindowM,
    );
    final passOf = [for (final h in hits) _nearestAnchor(h.alongM)];
    final closestM = List<double>.filled(
      anchorsM.length,
      followOffRouteThresholdM,
    );
    for (var i = 0; i < hits.length; i++) {
      final k = passOf[i];
      if (hits[i].offsetM < closestM[k]) closestM[k] = hits[i].offsetM;
    }
    final sums = [
      for (var k = 0; k < anchorsM.length; k++) _offsetSumsM[k] + closestM[k],
    ];
    final fixes = _fixes + 1;
    final join = FollowJoin._(
      joinM,
      offsetM,
      anchorsM,
      sums,
      _shiftsM,
      _settledFixes,
      fixes,
    );
    final fitting = sameRoad(track, hits);
    return (
      join: join,
      seen: [
        for (var i = 0; i < hits.length; i++)
          if (fitting.contains(hits[i]))
            (
              hit: hits[i],
              pass: passOf[i],
              anchorM: anchorsM[passOf[i]],
              signedM: _signedM(track, p, hits[i], passOf[i], distance),
              fitM: sums[passOf[i]] / fixes,
            ),
      ],
    );
  }

  /// How far along the route [hit] lies from the settled join on [pass],
  /// but no farther than [p] is from that point: a fix near a corner also
  /// lies close to the other leg, far along the route.
  double _signedM(
    RouteTrack track,
    LatLng p,
    RouteHit hit,
    int pass,
    DistanceCalculator distance,
  ) {
    final fromM = anchorsM[pass] + _shiftsM[pass];
    final at = track.pointAt(fromM);
    final straightM = distance.distanceBetween(p.lat, p.lng, at.lat, at.lng);
    final alongM = hit.alongM - fromM;
    return alongM.clamp(-straightM, straightM).toDouble();
  }

  int _nearestAnchor(double alongM) {
    var best = 0;
    for (var k = 1; k < anchorsM.length; k++) {
      if ((anchorsM[k] - alongM).abs() < (anchorsM[best] - alongM).abs()) {
        best = k;
      }
    }
    return best;
  }

  static List<RouteHit> _window(RouteTrack track, LatLng p, double joinM) =>
      track.hitsWithin(p, joinM - followJoinWindowM, joinM + followJoinWindowM);
}

/// The hits of [seen] whose pass the rider has fitted about as well as the
/// best since the join: within [followSameRoadBandM] of it on average.
List<JoinHit> bestFitting(List<JoinHit> seen) {
  if (seen.isEmpty) return const [];
  var bestM = seen.first.fitM;
  for (final h in seen) {
    if (h.fitM < bestM) bestM = h.fitM;
  }
  return [
    for (final h in seen)
      if (h.fitM <= bestM + followSameRoadBandM) h,
  ];
}
