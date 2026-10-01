import 'dart:math' as math;

import 'distance_calculator.dart';
import 'heading.dart' show LatLng;
import 'route_progress.dart';

/// Progress is first looked for no farther ahead than the rider is from the
/// progress point plus this, so a later pass of the road nearby (a hairpin,
/// an out-and-back's other leg) can't capture it.
const double _aheadSlackM = followOffRouteThresholdM;

/// Hits this far behind progress still count: a rider whose progress ran
/// ahead with the GPS error is found on their own pass.
const double _behindM = followOffRouteThresholdM;

/// Progress advances per fix at most this much more than the rider's pace.
const double _catchUpM = 2;

/// The share of the rest it catches up per fix beyond that.
const double _catchUpShare = 0.25;

/// Metres off the route one metre of misfit along it weighs.
const double _fitWeight = 0.5;

/// Metres off the route one metre behind progress (beyond the tolerance)
/// weighs.
const double _behindWeight = 0.5;

/// How far a GPS fix may fall behind progress without counting against it.
const double _behindToleranceM = 5;

/// Metres off the route one metre of the rider's heading against a pass
/// weighs.
const double _headingWeight = 1;

/// Metres per degree of latitude (mean Earth radius).
const double _metresPerDegree = 6371000 * math.pi / 180;

/// Progress on [route] at [p] once the direction is decided (Spec 18),
/// following [previous] and never going back.
///
/// On route, of [p]'s hits from a little behind progress to a little beyond
/// how far the rider is from the progress point, the one that best fits the
/// rider (see [_likeliest]); it advances progress by at most the rider's
/// [paceM] plus a little, then a share of the rest, so a fix thrown across a
/// corner, a hairpin or an out-and-back's turnaround is caught up with over
/// a few fixes instead of jumping progress to a later pass. [headingFrom] is
/// an earlier fix: which way the rider heads. Off route, Spec 17's
/// look-ahead and full search.
RouteProgress decidedProgress(
  RouteTrack route,
  RouteProgress previous,
  LatLng p, {
  required LatLng headingFrom,
  required double paceM,
  required DistanceCalculator distance,
}) {
  if (!previous.isOffRoute) {
    final fromM = previous.alongM;
    final at = route.pointAt(fromM);
    // How far on the rider is from the progress point, even while progress
    // holds there over several fixes.
    final onM = distance.distanceBetween(p.lat, p.lng, at.lat, at.lng);
    final hits = route.hitsWithin(
      p,
      fromM - _behindM,
      fromM + onM + _aheadSlackM,
    );
    if (hits.isNotEmpty) {
      final hit = _likeliest(route, hits, fromM, onM, headingFrom, p);
      final maxM = fromM + paceM + _catchUpM;
      final alongM = hit.alongM > maxM
          ? maxM + _catchUpShare * (hit.alongM - maxM)
          : math.max(hit.alongM, fromM);
      return route.progressAt(p, (alongM: alongM, offsetM: hit.offsetM));
    }
  }
  return route.locate(p, previous: previous)!;
}

/// The hit of [hits] that best fits a rider at [p], [onM] from the
/// progress point at [fromM]: close to the route, about as far along it
/// from there as the rider is from it (not a pass of the same road coming
/// back), not far behind progress (beyond the GPS error,
/// [_behindToleranceM]), and on a pass running the way the rider heads
/// (from [headingFrom]).
RouteHit _likeliest(
  RouteTrack route,
  List<RouteHit> hits,
  double fromM,
  double onM,
  LatLng headingFrom,
  LatLng p,
) {
  if (hits.length == 1) return hits.single;
  double cost(RouteHit h) {
    final alongM = h.alongM - fromM;
    final behindM = -alongM - _behindToleranceM;
    final headingM = _alongRouteM(route, h.alongM, headingFrom, p);
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
double _alongRouteM(RouteTrack route, double alongM, LatLng a, LatLng b) {
  final t = route.headingAt(alongM);
  final dx = (b.lng - a.lng) * math.cos(a.lat * math.pi / 180);
  final dy = b.lat - a.lat;
  return (dx * t.x + dy * t.y) * _metresPerDegree;
}
