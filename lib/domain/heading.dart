/// Heading-up helpers for the live ride map: the travel bearing the map
/// rotates to, and the route-line split that lets the line's tip follow the
/// gliding position marker.
library;

import 'dart:math' as math;

import 'distance_calculator.dart';

/// A point on the map (the same shape as the map's `RoutePoint`).
typedef LatLng = ({double lat, double lng});

const double _radiansPerDegree = math.pi / 180;
const double _degreesPerRadian = 180 / math.pi;
const double _fullCircleDegrees = 360;

/// Initial great-circle bearing from [from] towards [to], in degrees clockwise
/// from north, normalized to `[0, 360)` — north 0°, east 90°, south 180°,
/// west 270° (never negative, so it can feed a map rotation directly).
double bearingDegrees(LatLng from, LatLng to) {
  final fromLat = from.lat * _radiansPerDegree;
  final toLat = to.lat * _radiansPerDegree;
  final deltaLng = (to.lng - from.lng) * _radiansPerDegree;
  final east = math.sin(deltaLng) * math.cos(toLat);
  final north = math.cos(fromLat) * math.sin(toLat) -
      math.sin(fromLat) * math.cos(toLat) * math.cos(deltaLng);
  final signedDegrees = math.atan2(east, north) * _degreesPerRadian;
  return (signedDegrees + _fullCircleDegrees) % _fullCircleDegrees;
}

/// Below this travel distance a position change is treated as GPS jitter
/// (or standing still), not movement: the fix wanders a few metres even when
/// the rider stands still, and a bearing between two such fixes would spin
/// the heading-up map at random.
const double _minHeadingTravelMetres = 5;

/// A route polyline needs at least this many points before its newest
/// segment can be split off as a tail.
const int _minPointsForTail = 2;

/// Bearing of travel from [anchor] (the position the current heading was
/// taken from) to [current], in degrees as [bearingDegrees] — or `null` while
/// the rider has moved less than [minMetres] from [anchor].
///
/// `null` means "keep the previous heading": standing still or GPS jitter
/// must not rotate the map. Only once the rider has really moved does the
/// caller take a new heading and move its anchor to [current].
double? travelBearing(LatLng anchor, LatLng current,
    {double minMetres = _minHeadingTravelMetres}) {
  final movedMetres = const HaversineDistanceCalculator()
      .distanceBetween(anchor.lat, anchor.lng, current.lat, current.lng);
  if (movedMetres < minMetres) return null;
  return bearingDegrees(anchor, current);
}

/// The live route line split into a fixed [body] and the start of a moving
/// tail (`tailStart == null` → no tail, draw [body] as-is).
typedef RouteTailSplit = ({List<LatLng> body, LatLng? tailStart});

/// Splits the recorded route [points] so its tip can follow the position
/// marker, which glides (animates) towards each new fix instead of jumping.
///
/// When [current] is the newest recorded point, drawing the full line would
/// put its tip at the fix before the gliding marker gets there. So the newest
/// point is dropped from [body], and [tailStart] (the second-to-last point)
/// is where the map draws a short tail to the marker's animated position.
/// Otherwise — too few points, or [current] was filtered out and never
/// recorded — [body] is all of [points] and there is no tail.
RouteTailSplit splitRouteTail(List<LatLng> points, LatLng? current) {
  if (points.length >= _minPointsForTail && current == points.last) {
    final newestIndex = points.length - 1;
    return (
      body: points.sublist(0, newestIndex),
      tailStart: points[newestIndex - 1],
    );
  }
  return (body: points, tailStart: null);
}
