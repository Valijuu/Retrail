import 'dart:math' as math;

import 'package:retrail/domain/heading.dart' show LatLng;
import 'package:retrail/domain/route_progress.dart';

// Simulated routes and rides for the follow scenario suite. Realism gaps: the
// rider takes corners exactly on the route and rides at a steady pace, and
// fixes come every second without outliers, dropouts or multipath jumps
// (the real-ride replay group covers real GPS).

/// Metres per degree of latitude for the Haversine radius (6371000 m).
const _mPerDeg = 6371000 * math.pi / 180;

/// A point [northM] metres north and [eastM] metres east of (48°, 11°).
LatLng at(double northM, double eastM) => (
  lat: 48.0 + northM / _mPerDeg,
  lng: 11.0 + eastM / (_mPerDeg * math.cos(48.0 * math.pi / 180)),
);

/// A position in local metres (north, east).
typedef Xy = ({double n, double e});

/// A reference route in local metres, with the [RouteTrack] the tracker sees.
class SimRoute {
  SimRoute(this.name, this.vertices)
    : track = RouteTrack([for (final v in vertices) at(v.n, v.e)]),
      cumulativeM = _cumulative(vertices);

  final String name;
  final List<Xy> vertices;
  final RouteTrack track;
  final List<double> cumulativeM;

  double get lengthM => cumulativeM.last;
  bool get isLoop => track.isLoop;

  static List<double> _cumulative(List<Xy> vs) {
    final out = [0.0];
    for (var i = 1; i < vs.length; i++) {
      out.add(out.last + dist(vs[i - 1], vs[i]));
    }
    return out;
  }

  /// True when every point lies within [sameRoadM] of the point as far from
  /// the other end: the route runs both ways along one road (an
  /// out-and-back), so riding it either way is the same ride.
  late final bool isSameRoad = () {
    for (var s = 0.0; s <= lengthM; s += 2) {
      if (dist(pointAt(s), pointAt(lengthM - s)) > sameRoadM) return false;
    }
    return true;
  }();

  /// The nearest point on the route to [p], as route metres and distance.
  /// Points within 3 m of the nearest that lie closer to [nearS] along the
  /// route win (a road ridden twice); on a loop the result is unwrapped next
  /// to [nearS].
  ({double s, double offsetM}) project(Xy p, {double? nearS}) {
    final candidates = <({double s, double offsetM})>[];
    for (var i = 0; i < vertices.length - 1; i++) {
      final a = vertices[i], b = vertices[i + 1];
      final dn = b.n - a.n, de = b.e - a.e, len2 = dn * dn + de * de;
      final t = len2 == 0
          ? 0.0
          : (((p.n - a.n) * dn + (p.e - a.e) * de) / len2).clamp(0.0, 1.0);
      final q = (n: a.n + dn * t, e: a.e + de * t);
      candidates.add((
        s: cumulativeM[i] + t * (cumulativeM[i + 1] - cumulativeM[i]),
        offsetM: dist(p, q),
      ));
    }
    final best = candidates.map((c) => c.offsetM).reduce(math.min);
    double unwrapped(double s) {
      if (!isLoop || nearS == null) return s;
      return s + ((nearS - s) / lengthM).round() * lengthM;
    }

    ({double s, double offsetM})? pick;
    for (final c in candidates) {
      if (c.offsetM > best + 3) continue;
      final u = (s: unwrapped(c.s), offsetM: c.offsetM);
      if (pick == null ||
          (nearS == null
              ? u.offsetM < pick.offsetM
              : (u.s - nearS).abs() < (pick.s - nearS).abs())) {
        pick = u;
      }
    }
    return pick!;
  }

  /// [s] on the route: wrapped round a loop, clamped to an open route.
  double wrap(double s) => isLoop
      ? ((s % lengthM) + lengthM) % lengthM
      : s.clamp(0.0, lengthM).toDouble();

  /// The leg index and its parameter at [s].
  (int, double) _legAt(double s) {
    final w = wrap(s);
    var i = 0;
    while (i < vertices.length - 2 && cumulativeM[i + 1] < w) {
      i++;
    }
    final len = cumulativeM[i + 1] - cumulativeM[i];
    return (i, len == 0 ? 0 : (w - cumulativeM[i]) / len);
  }

  Xy pointAt(double s) {
    final (i, t) = _legAt(s);
    final a = vertices[i], b = vertices[i + 1];
    return (n: a.n + (b.n - a.n) * t, e: a.e + (b.e - a.e) * t);
  }

  /// The unit normal at [s] pointing away from the vertex centroid.
  Xy outwardNormalAt(double s) {
    final (i, _) = _legAt(s);
    final a = vertices[i], b = vertices[i + 1];
    final len = dist(a, b);
    var normal = (n: -(b.e - a.e) / len, e: (b.n - a.n) / len);
    final c = (
      n: vertices.map((v) => v.n).reduce((x, y) => x + y) / vertices.length,
      e: vertices.map((v) => v.e).reduce((x, y) => x + y) / vertices.length,
    );
    final p = pointAt(s);
    if ((p.n - c.n) * normal.n + (p.e - c.e) * normal.e < 0) {
      normal = (n: -normal.n, e: -normal.e);
    }
    return normal;
  }
}

double dist(Xy a, Xy b) => math.sqrt(_sq(a.n - b.n) + _sq(a.e - b.e));

/// Another pass of the road the rider rode (an out-and-back's legs, a
/// lollipop's stem) counts as the same road within this.
const sameRoadM = 5.0;

/// Rider speed ranges at 1 Hz, m/s.
typedef Speed = ({double min, double max});
const Speed slow = (min: 1, max: 2);
const Speed cruise = (min: 3, max: 5);
const Speed fast = (min: 5, max: 8);
double _sq(double x) => x * x;

/// What the rider does, leg by leg, from [startS] (route metres, unwrapped:
/// on a loop it may run past either end).
class Plan {
  Plan(this.startS);

  final double startS;
  final List<_Leg> _legs = [];

  /// Rides along the route to [toS]; backwards when it lies behind.
  void ride(double toS) => _legs.add(_Ride(toS));

  /// Stands still for [seconds] fixes.
  void stand(int seconds) => _legs.add(_Stand(seconds));

  /// Leaves the route [depthM] away from it and comes back to the same spot.
  void excursion(double depthM) => _legs.add(_Excursion(depthM));

  /// Calls `flip()` [delay] fixes after the last fix so far.
  void flipAfter(int delay) => _legs.add(_Flip(delay));
}

sealed class _Leg {}

class _Ride extends _Leg {
  _Ride(this.toS);
  final double toS;
}

class _Stand extends _Leg {
  _Stand(this.seconds);
  final int seconds;
}

class _Excursion extends _Leg {
  _Excursion(this.depthM);
  final double depthM;
}

class _Flip extends _Leg {
  _Flip(this.delay);
  final int delay;
}

/// One 1 Hz fix of the true ride: position and route metres (unwrapped).
typedef TrueFix = ({Xy pos, double s});

/// The true ride of [plan] at [speed] m/s (±10 % per fix), and the fix index
/// after which `flip()` is called (null for none).
({List<TrueFix> fixes, int? flipAt}) generate(
  SimRoute route,
  Plan plan,
  double speed,
  math.Random r,
) {
  var s = plan.startS;
  final fixes = <TrueFix>[(pos: route.pointAt(s), s: s)];
  int? flipAt;
  double step() => speed * (0.9 + 0.2 * r.nextDouble());
  for (final leg in plan._legs) {
    switch (leg) {
      case _Ride(:final toS):
        final dir = toS > s ? 1 : -1;
        while (s != toS) {
          s = dir > 0 ? math.min(s + step(), toS) : math.max(s - step(), toS);
          fixes.add((pos: route.pointAt(s), s: s));
        }
      case _Stand(:final seconds):
        for (var i = 0; i < seconds; i++) {
          fixes.add((pos: route.pointAt(s), s: s));
        }
      case _Excursion(:final depthM):
        final base = route.pointAt(s), normal = route.outwardNormalAt(s);
        Xy off(double d) =>
            (n: base.n + normal.n * d, e: base.e + normal.e * d);
        var d = 0.0;
        while (d < depthM) {
          d = math.min(d + step(), depthM);
          fixes.add((pos: off(d), s: s));
        }
        while (d > 0) {
          d = math.max(d - step(), 0);
          fixes.add((pos: off(d), s: s));
        }
      case _Flip(:final delay):
        flipAt = fixes.length - 1 + delay;
    }
  }
  return (fixes: fixes, flipAt: flipAt);
}
