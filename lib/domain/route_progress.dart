import 'dart:math' as math;

import 'distance_calculator.dart';
import 'heading.dart' show LatLng;

/// Farther than this from the reference route counts as off route.
const double followOffRouteThresholdM = 30;

/// Within this of the route's last point (and far enough along, see
/// [followFinishMinShare]) the finish counts as reached.
const double followFinishRadiusM = 30;

/// Share of the route that must be behind the rider before the finish counts.
/// On a loop the start lies within [followFinishRadiusM] of the finish.
const double followFinishMinShare = 0.9;

/// While on route, only this much route ahead of the last progress is
/// searched, so a crossing or a parallel leg further on can't capture the
/// position.
const double followLookAheadM = 500;

/// On-route candidates farther apart than this along the route are separate
/// passes of the route past the rider (loop start vs finish, out-and-back legs).
const double _passGapM = 2 * followOffRouteThresholdM;

/// Candidates whose offsets differ by at most this are a tie; the one less far
/// along the route wins.
const double _offsetTieM = 1;

/// A cut this close to a vertex (float noise from summed Haversine legs)
/// lands on the vertex instead of adding a duplicate point.
const double _vertexSnapM = 1e-6;

/// Where the rider is relative to the reference route.
class RouteProgress {
  const RouteProgress({
    required this.alongM,
    required this.remainingM,
    required this.offsetM,
    required this.isOffRoute,
    required this.isFinished,
    required this.hasJoined,
  });

  /// Distance along the route to the rider's projected position.
  final double alongM;
  final double remainingM;

  /// Distance from the rider to the route.
  final double offsetM;
  final bool isOffRoute;
  final bool isFinished;

  /// True once the rider has been on the route at least once. Before that the
  /// UI shows "X to the route" instead of "Off route".
  final bool hasJoined;

  @override
  String toString() =>
      'RouteProgress(along: $alongM, remaining: $remainingM, '
      'offset: $offsetM, off: $isOffRoute, finished: $isFinished, '
      'joined: $hasJoined)';
}

/// A route cut at a distance along it: the part behind and the part ahead,
/// sharing the cut point.
typedef RouteSplit = ({List<LatLng> done, List<LatLng> ahead});

/// A reference route with its cumulative distances, locating positions on it.
class RouteTrack {
  RouteTrack(
    List<LatLng> points, {
    DistanceCalculator distance = const HaversineDistanceCalculator(),
  }) : points = List.unmodifiable(points),
       _distance = distance,
       cumulativeM = List.unmodifiable(_cumulative(points, distance));

  final List<LatLng> points;

  /// Distance from the first point to each point.
  final List<double> cumulativeM;
  final DistanceCalculator _distance;

  double get lengthM => cumulativeM.isEmpty ? 0 : cumulativeM.last;

  static List<double> _cumulative(List<LatLng> points, DistanceCalculator d) {
    final out = <double>[];
    var sum = 0.0;
    for (var i = 0; i < points.length; i++) {
      if (i > 0) {
        final a = points[i - 1], b = points[i];
        sum += d.distanceBetween(a.lat, a.lng, b.lat, b.lng);
      }
      out.add(sum);
    }
    return out;
  }

  /// Projects [position] onto the route. [previous] is the last result: while
  /// on route only the window ahead of it is searched and progress never
  /// decreases; the first fix and a rejoin search the whole route. Null for a
  /// route without length.
  RouteProgress? locate(LatLng position, {RouteProgress? previous}) {
    if (lengthM <= 0) return null;
    if (previous != null && previous.hasJoined && !previous.isOffRoute) {
      final windowOnRoute = _candidates(
        position,
        previous.alongM,
        math.min(lengthM, previous.alongM + followLookAheadM),
      ).where((c) => c.offsetM <= followOffRouteThresholdM).toList();
      if (windowOnRoute.isNotEmpty) {
        return _onRoute(position, _passes(windowOnRoute).first);
      }
    }
    final all = _candidates(position, 0, lengthM);
    final onRoute = all
        .where((c) => c.offsetM <= followOffRouteThresholdM)
        .toList();
    if (onRoute.isEmpty) {
      final along = previous?.alongM ?? 0;
      return RouteProgress(
        alongM: along,
        remainingM: lengthM - along,
        offsetM: all.map((c) => c.offsetM).reduce(math.min),
        isOffRoute: true,
        isFinished: false,
        hasJoined: previous?.hasJoined ?? false,
      );
    }
    final passes = _passes(onRoute);
    final pick = previous != null && previous.hasJoined
        ? _nearestPass(passes, previous.alongM)
        : passes.first;
    return _onRoute(position, pick);
  }

  /// Cuts the route [alongM] metres from the start (clamped to the route). A
  /// cut within [_vertexSnapM] of a vertex lands on it, so neither half gets a
  /// near-duplicate point.
  RouteSplit splitAt(double alongM) {
    if (lengthM <= 0 || alongM <= _vertexSnapM) {
      return (done: const [], ahead: points);
    }
    if (alongM >= lengthM - _vertexSnapM) {
      return (done: points, ahead: const []);
    }
    var i = 0;
    while (i < points.length - 2 && cumulativeM[i + 1] < alongM) {
      i++;
    }
    if (cumulativeM[i + 1] - alongM <= _vertexSnapM) {
      return (done: points.sublist(0, i + 2), ahead: points.sublist(i + 1));
    }
    if (alongM - cumulativeM[i] <= _vertexSnapM) {
      return (done: points.sublist(0, i + 1), ahead: points.sublist(i));
    }
    final t = (alongM - cumulativeM[i]) / (cumulativeM[i + 1] - cumulativeM[i]);
    final cut = _lerp(points[i], points[i + 1], t);
    return (
      done: [...points.sublist(0, i + 1), cut],
      ahead: [cut, ...points.sublist(i + 1)],
    );
  }

  RouteProgress _onRoute(LatLng position, _Candidate c) {
    final end = points.last;
    final toEnd = _distance.distanceBetween(
      position.lat,
      position.lng,
      end.lat,
      end.lng,
    );
    return RouteProgress(
      alongM: c.alongM,
      remainingM: math.max(0, lengthM - c.alongM),
      offsetM: c.offsetM,
      isOffRoute: false,
      isFinished:
          toEnd <= followFinishRadiusM &&
          c.alongM >= followFinishMinShare * lengthM,
      hasJoined: true,
    );
  }

  /// The nearest point of each segment overlapping [fromM]..[toM] (clamped to
  /// that range), with its distance along the route and to [p].
  List<_Candidate> _candidates(LatLng p, double fromM, double toM) {
    final out = <_Candidate>[];
    for (var i = 0; i < points.length - 1; i++) {
      final start = cumulativeM[i];
      final len = cumulativeM[i + 1] - start;
      if (len <= 0 || cumulativeM[i + 1] < fromM || start > toM) continue;
      final tMin = math.max(0.0, (fromM - start) / len);
      final tMax = math.min(1.0, (toM - start) / len);
      if (tMin > tMax) continue;
      final t = _projectT(points[i], points[i + 1], p).clamp(tMin, tMax);
      final q = _lerp(points[i], points[i + 1], t);
      out.add(
        _Candidate(
          alongM: start + t * len,
          offsetM: _distance.distanceBetween(p.lat, p.lng, q.lat, q.lng),
        ),
      );
    }
    return out;
  }

  /// Segment parameter of [p]'s perpendicular foot on a→b, in a local
  /// equirectangular frame (longitude scaled by cos(latitude)).
  static double _projectT(LatLng a, LatLng b, LatLng p) {
    final k = math.cos(a.lat * math.pi / 180);
    final bx = (b.lng - a.lng) * k, by = b.lat - a.lat;
    final px = (p.lng - a.lng) * k, py = p.lat - a.lat;
    final dd = bx * bx + by * by;
    return dd == 0 ? 0 : (px * bx + py * by) / dd;
  }

  static LatLng _lerp(LatLng a, LatLng b, double t) =>
      (lat: a.lat + (b.lat - a.lat) * t, lng: a.lng + (b.lng - a.lng) * t);

  static _Candidate? _closest(Iterable<_Candidate> cs) {
    _Candidate? best;
    for (final c in cs) {
      if (best == null ||
          c.offsetM < best.offsetM - _offsetTieM ||
          (c.offsetM <= best.offsetM + _offsetTieM && c.alongM < best.alongM)) {
        best = c;
      }
    }
    return best;
  }

  /// The pass closest along the route to [alongM]; a tie goes to the one ahead.
  static _Candidate _nearestPass(List<_Candidate> passes, double alongM) {
    var best = passes.first;
    for (final c in passes.skip(1)) {
      final d = (c.alongM - alongM).abs(), bd = (best.alongM - alongM).abs();
      if (d < bd || (d == bd && c.alongM > best.alongM)) best = c;
    }
    return best;
  }

  /// Groups [onRoute] into passes (along-gap > [_passGapM]) and returns each
  /// pass's closest candidate, in route order.
  static List<_Candidate> _passes(List<_Candidate> onRoute) {
    final sorted = [...onRoute]..sort((a, b) => a.alongM.compareTo(b.alongM));
    final passes = <_Candidate>[];
    var group = <_Candidate>[sorted.first];
    for (final c in sorted.skip(1)) {
      if (c.alongM - group.last.alongM > _passGapM) {
        passes.add(_closest(group)!);
        group = [c];
      } else {
        group.add(c);
      }
    }
    passes.add(_closest(group)!);
    return passes;
  }
}

class _Candidate {
  const _Candidate({required this.alongM, required this.offsetM});
  final double alongM;
  final double offsetM;
}
