import 'dart:math' as math;

import 'distance_calculator.dart';
import 'heading.dart' show LatLng;
import 'ride_outline.dart' show OutlineBounds, segmentDistanceM;

/// One ride as the route match sees it (#114).
class RouteMatchEntry {
  const RouteMatchEntry({
    required this.rideId,
    required this.bounds,
    required this.points,
    this.followedRideId,
  });

  final int rideId;
  final int? followedRideId;
  final OutlineBounds? bounds;
  final List<LatLng> points;
}

/// Which rides lie on the same line (#114).
class RouteMatch {
  const RouteMatch._();

  /// Ride id → group key (the smallest ride id of its group) for every entry.
  static Map<int, int> groups(List<RouteMatchEntry> entries) {
    final unionFind = _UnionFind([for (final e in entries) e.rideId]);

    for (final e in entries) {
      final followed = e.followedRideId;
      if (followed != null && unionFind.contains(followed)) {
        unionFind.join(e.rideId, followed);
      }
    }

    for (var i = 0; i < entries.length; i++) {
      for (var j = i + 1; j < entries.length; j++) {
        if (_onSameLine(entries[i], entries[j])) {
          unionFind.join(entries[i].rideId, entries[j].rideId);
        }
      }
    }
    return {for (final e in entries) e.rideId: unionFind.find(e.rideId)};
  }

  static const _distance = HaversineDistanceCalculator();

  /// Metres within which every point of one outline must lie of the other.
  static const toleranceM = 30.0;

  static const _minPointsForLine = 2;

  static const _metresPerDegree = 111195.0;
  static const _degreesPerHalfTurn = 180;
  static const _radiansPerDegree = math.pi / _degreesPerHalfTurn;

  /// Whether the boxes, each grown by the tolerance, overlap. A box that
  /// wraps across ±180 (west beyond east) is not ruled out.
  static bool _boxesNear(OutlineBounds? a, OutlineBounds? b) {
    if (a == null || b == null) return false;
    if (a.west > a.east || b.west > b.east) return true;
    final maxLat = [
      a.south,
      a.north,
      b.south,
      b.north,
    ].map((v) => v.abs()).reduce((x, y) => x > y ? x : y);
    final latMargin = toleranceM / _metresPerDegree;
    final lngMargin =
        toleranceM / (_metresPerDegree * math.cos(maxLat * _radiansPerDegree));
    return a.south - latMargin <= b.north &&
        b.south - latMargin <= a.north &&
        a.west - lngMargin <= b.east &&
        b.west - lngMargin <= a.east;
  }

  static bool _onSameLine(RouteMatchEntry a, RouteMatchEntry b) =>
      _boxesNear(a.bounds, b.bounds) &&
      a.points.length >= _minPointsForLine &&
      b.points.length >= _minPointsForLine &&
      _allNear(a.points, b.points) &&
      _allNear(b.points, a.points);

  static bool _allNear(List<LatLng> points, List<LatLng> line) {
    for (final p in points) {
      var nearest = double.infinity;
      for (var i = 0; i + 1 < line.length; i++) {
        final d = segmentDistanceM(p, line[i], line[i + 1], _distance);
        if (d < nearest) nearest = d;
      }
      if (nearest > toleranceM) return false;
    }
    return true;
  }
}

/// Disjoint sets of ride ids; the smallest id of a set is its root.
class _UnionFind {
  _UnionFind(Iterable<int> ids) : _parent = {for (final id in ids) id: id};

  final Map<int, int> _parent;

  bool contains(int id) => _parent.containsKey(id);

  int find(int id) {
    var root = id;
    while (_parent[root] != root) {
      root = _parent[root]!;
    }
    return root;
  }

  void join(int a, int b) {
    final rootA = find(a), rootB = find(b);
    if (rootA == rootB) return;
    // The smaller id stays the root, so it is the group's key.
    if (rootA < rootB) {
      _parent[rootB] = rootA;
    } else {
      _parent[rootA] = rootB;
    }
  }
}
