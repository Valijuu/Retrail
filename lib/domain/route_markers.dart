import 'dart:math' as math;

import 'distance_calculator.dart';

/// Endpoints at most this far apart (inclusive) count as a closed loop: the
/// rider came back to where they started, so a single combined start/finish
/// marker is drawn instead of separate start and finish markers.
const _maxLoopGapMetres = 30.0;

/// How a route's endpoints are marked on a map.
///
/// Shared by the preview PNG painter, the offline sketch and the MapLibre map
/// so all three mark the same ride identically.
enum RouteEndpointStyle {
  /// No points recorded — draw no markers.
  none,

  /// A single point (standstill ride) — draw only the start marker.
  startOnly,

  /// Start and finish are apart — draw separate start and finish markers.
  open,

  /// Start and finish lie within [_maxLoopGapMetres] — draw one combined marker.
  loop,
}

/// Classifies which endpoint markers a route of [points] gets.
///
/// Only the first and last point matter; where the ride went in between is
/// irrelevant. The endpoint gap is measured with [calc] (Haversine by default)
/// and compared against [_maxLoopGapMetres], inclusive.
RouteEndpointStyle routeEndpointStyle(
  List<({double lat, double lng})> points, {
  DistanceCalculator calc = const HaversineDistanceCalculator(),
}) {
  if (points.isEmpty) return RouteEndpointStyle.none;
  if (points.length == 1) return RouteEndpointStyle.startOnly;
  final start = points.first, finish = points.last;
  final endpointGap =
      calc.distanceBetween(start.lat, start.lng, finish.lat, finish.lng);
  return endpointGap <= _maxLoopGapMetres
      ? RouteEndpointStyle.loop
      : RouteEndpointStyle.open;
}

/// Where to draw direction arrows along a screen-space [polyline].
///
/// Walks the polyline by arc length and places an arrow at every multiple of
/// [spacing] that lies within `[endMargin, totalLength − endMargin]`, so no
/// arrow crowds the start or finish marker. Each arrow sits on its segment and
/// carries that segment's heading as `atan2(dy, dx)` in radians — canvas
/// convention with y pointing down, so a downward segment is π/2.
///
/// Zero-length segments (duplicate points) are skipped, so they never yield a
/// NaN angle. Fewer than two points, or a line shorter than both margins,
/// yields no arrows.
List<({double x, double y, double angle})> directionArrows(
  List<({double x, double y})> polyline, {
  required double spacing,
  required double endMargin,
}) {
  final segmentLengths = [
    for (var i = 1; i < polyline.length; i++)
      _distance(polyline[i - 1], polyline[i]),
  ];
  final totalLength = segmentLengths.fold(0.0, (sum, len) => sum + len);
  final lastArrowAt = totalLength - endMargin;

  final arrows = <({double x, double y, double angle})>[];
  var walkedLength = 0.0;
  var nextArrowAt = spacing;
  for (var i = 1; i < polyline.length; i++) {
    final segmentLength = segmentLengths[i - 1];
    if (segmentLength == 0) continue;
    final from = polyline[i - 1], to = polyline[i];
    final dx = to.x - from.x, dy = to.y - from.y;
    while (nextArrowAt <= walkedLength + segmentLength) {
      if (nextArrowAt >= endMargin && nextArrowAt <= lastArrowAt) {
        final t = (nextArrowAt - walkedLength) / segmentLength;
        arrows.add(
            (x: from.x + dx * t, y: from.y + dy * t, angle: math.atan2(dy, dx)));
      }
      nextArrowAt += spacing;
    }
    walkedLength += segmentLength;
  }
  return arrows;
}

/// Straight-line distance between two screen-space points.
double _distance(({double x, double y}) a, ({double x, double y}) b) {
  final dx = b.x - a.x, dy = b.y - a.y;
  return math.sqrt(dx * dx + dy * dy);
}
