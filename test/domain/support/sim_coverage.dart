import 'dart:math' as math;

import 'sim_route.dart';

/// Ridden intervals may reach this far along the route beyond the truly
/// ridden road.
const riddenSlackM = 40.0;

/// The truly ridden stretch since the join, in unwrapped route metres: the
/// rider's route position moves continuously, so it is one range.
class Coverage {
  Coverage(this.route);

  final SimRoute route;
  double? _lo, _hi;

  void add(double s) {
    _lo = math.min(_lo ?? s, s);
    _hi = math.max(_hi ?? s, s);
  }

  /// True when every part of [intervals] lies within [riddenSlackM] along
  /// the route of the ridden road: the ridden stretch, or another pass of the
  /// same road within [sameRoadM] of it (an out-and-back's legs, a lollipop's
  /// stem).
  bool covers(List<(double, double)> intervals) {
    for (final (from, to) in intervals) {
      if (_alongCovers(from, to)) continue;
      for (var k = (from / _sampleM).ceil(); k * _sampleM < to; k++) {
        if (!_coversSample(k)) return false;
      }
      if (!_coversPoint(from) || !_coversPoint(to)) return false;
    }
    return true;
  }

  /// Sample spacing along the route.
  static const _sampleM = 2.0;

  int get _sampleCount => (route.lengthM / _sampleM).ceil();

  /// Samples known to lie on the ridden road, and samples known to be
  /// covered: both only grow with the ridden stretch.
  final Set<int> _ridden = {}, _covered = {};

  bool _coversSample(int k) {
    if (_covered.contains(k)) return true;
    final covered = _coversPoint(k * _sampleM);
    if (covered) _covered.add(k);
    return covered;
  }

  bool _coversPoint(double m) {
    if (_alongCovers(m, m)) return true;
    final k0 = (m / _sampleM).round(), reach = riddenSlackM ~/ _sampleM;
    int wrapped(int k) => route.isLoop ? k % _sampleCount : k;
    for (var j = -reach; j <= reach; j++) {
      if (_ridden.contains(wrapped(k0 + j))) return true;
    }
    for (var j = 0; j <= reach; j++) {
      if (_onRiddenRoad(wrapped(k0 + j)) || _onRiddenRoad(wrapped(k0 - j))) {
        return true;
      }
    }
    return false;
  }

  bool _onRiddenRoad(int k) {
    if (_ridden.contains(k)) return true;
    final m = k * _sampleM;
    if (!route.isLoop && (m < 0 || m > route.lengthM)) return false;
    final onIt = _distanceToRidden(route.pointAt(m)) <= sameRoadM;
    if (onIt) _ridden.add(k);
    return onIt;
  }

  bool _alongCovers(double from, double to) {
    final lo = _lo, hi = _hi;
    if (lo == null || hi == null) return false;
    final dLo = lo - riddenSlackM, dHi = hi + riddenSlackM;
    if (!route.isLoop) return from >= dLo && to <= dHi;
    final lapM = route.lengthM;
    if (dHi - dLo >= lapM) return true;
    for (var k = ((dLo - to) / lapM).floor(); k * lapM + from <= dHi; k++) {
      if (from + k * lapM >= dLo && to + k * lapM <= dHi) return true;
    }
    return false;
  }

  /// Distance from [p] to the route along the ridden stretch.
  double _distanceToRidden(Xy p) {
    final lo = _lo, hi = _hi;
    if (lo == null || hi == null) return double.infinity;
    final lapM = route.lengthM, cum = route.cumulativeM, vs = route.vertices;
    var best = double.infinity;
    final firstLap = route.isLoop ? (lo / lapM).floor() : 0;
    final lastLap = route.isLoop ? (hi / lapM).floor() : 0;
    for (var lap = firstLap; lap <= lastLap; lap++) {
      for (var i = 0; i < vs.length - 1; i++) {
        final a0 = cum[i] + lap * lapM, b0 = cum[i + 1] + lap * lapM;
        final from = math.max(a0, lo), to = math.min(b0, hi);
        if (from > to || b0 == a0) continue;
        final a = vs[i], b = vs[i + 1];
        final dn = b.n - a.n, de = b.e - a.e, len2 = dn * dn + de * de;
        final t = (((p.n - a.n) * dn + (p.e - a.e) * de) / len2).clamp(
          (from - a0) / (b0 - a0),
          (to - a0) / (b0 - a0),
        );
        best = math.min(best, dist(p, (n: a.n + dn * t, e: a.e + de * t)));
      }
    }
    return best;
  }
}
