import 'dart:math' as math;

import 'distance_calculator.dart';
import 'heading.dart' show LatLng;
import 'ride_outline.dart';

/// Metres on the ground that one logical pixel covers (MapLibre 512 px tiles).
double metresPerPixel({required double zoom, required double latitude}) =>
    _metresPerPixelEquatorZoom0 *
    math.cos(_radians(latitude)) /
    math.pow(_scalePerZoomLevel, zoom);

/// Metres per logical pixel at zoom 0 on the equator (512 px tiles).
const _metresPerPixelEquatorZoom0 = 78271.517;

/// Each zoom level halves the ground one pixel covers.
const _scalePerZoomLevel = 2;

const _degreesPerHalfTurn = 180;

double _radians(double degrees) => degrees * math.pi / _degreesPerHalfTurn;

/// A tap hits a line within this many logical pixels.
const double tapTolerancePx = 24;

/// A ride the tap is tested against; its outline decodes only when needed.
class OutlineCandidate {
  const OutlineCandidate({
    required this.rideId,
    required this.timestampMs,
    required this.bounds,
    required this.outline,
  });

  final int rideId;
  final int timestampMs;
  final OutlineBounds? bounds;
  final RideOutline Function() outline;
}

/// A ride under the tap.
class OutlineHit {
  const OutlineHit({
    required this.rideId,
    required this.distanceM,
    required this.isBest,
  });

  final int rideId;
  final double distanceM;
  final bool isBest;

  static List<OutlineHit> find({
    required LatLng tap,
    required double zoom,
    required List<OutlineCandidate> candidates,
    required Set<int> bestRideIds,
    DistanceCalculator distance = const HaversineDistanceCalculator(),
  }) {
    final toleranceM =
        tapTolerancePx * metresPerPixel(zoom: zoom, latitude: tap.lat);
    final found = <({OutlineHit hit, int timestampMs})>[];
    for (final c in candidates) {
      final box = c.bounds;
      if (box == null || !_nearBox(box, tap, toleranceM)) continue;
      final nearest = _nearestSegmentM(tap, c.outline().points, distance);
      if (nearest > toleranceM) continue;
      found.add((
        hit: OutlineHit(
          rideId: c.rideId,
          distanceM: nearest,
          isBest: bestRideIds.contains(c.rideId),
        ),
        timestampMs: c.timestampMs,
      ));
    }
    found.sort((a, b) {
      final byDistance = a.hit.distanceM.compareTo(b.hit.distanceM);
      return byDistance != 0
          ? byDistance
          : b.timestampMs.compareTo(a.timestampMs);
    });
    return [for (final f in found) f.hit];
  }

  /// Metres from [tap] to the nearest segment of [points]; infinity when
  /// there is no segment.
  static double _nearestSegmentM(
    LatLng tap,
    List<LatLng> points,
    DistanceCalculator distance,
  ) {
    var nearest = double.infinity;
    for (var i = 1; i < points.length; i++) {
      nearest = math.min(
        nearest,
        segmentDistanceM(tap, points[i - 1], points[i], distance),
      );
    }
    return nearest;
  }

  /// Whether [tap] lies within [toleranceM] of [box] (with a safety margin),
  /// so far outlines are rejected before they are decoded.
  static bool _nearBox(OutlineBounds box, LatLng tap, double toleranceM) {
    final dLat = toleranceM * _boundsMargin / _metresPerDegreeLat;
    final cosLat = math.max(
      math.cos(_radians(math.min(tap.lat.abs() + dLat, _maxLatitude))),
      _minCosLatitude,
    );
    final dLng = dLat / cosLat;
    return tap.lat >= box.south - dLat &&
        tap.lat <= box.north + dLat &&
        tap.lng >= box.west - dLng &&
        tap.lng <= box.east + dLng;
  }

  /// Radius of the sphere the default Haversine distance uses.
  static const _earthRadiusM = 6371000;
  static const _metresPerDegreeLat =
      _earthRadiusM * math.pi / _degreesPerHalfTurn;

  /// Safety factor on the grown bounds, so the box never rejects a ride the
  /// segment test would accept.
  static const _boundsMargin = 1.05;

  /// Longitude degrees stop widening here, so the box stays finite at the
  /// poles.
  static const _maxLatitude = 89.0;
  static const _minCosLatitude = 0.01;
}
