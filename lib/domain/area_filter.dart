import 'dart:math' as math;

import 'distance_calculator.dart';
import 'heading.dart' show LatLng;
import 'ride_outline.dart';

/// The "rides around here" filter (#96): a pinned point and a radius in
/// whole kilometres.
class AreaFilter {
  AreaFilter({required this.pin, double radiusKm = defaultRadiusKm})
    : radiusKm = radiusKm.clamp(minRadiusKm, maxRadiusKm).roundToDouble();

  static const double minRadiusKm = 1;
  static const double maxRadiusKm = 50;
  static const double defaultRadiusKm = 5;

  final LatLng pin;
  final double radiusKm;

  AreaFilter copyWith({LatLng? pin, double? radiusKm}) =>
      AreaFilter(pin: pin ?? this.pin, radiusKm: radiusKm ?? this.radiusKm);

  bool matches(
    RideOutline outline, {
    DistanceCalculator distance = const HaversineDistanceCalculator(),
  }) {
    final points = outline.points;
    final box = outline.bounds;
    if (points.length < _minPointsForLine) return false;
    if (box == null || !couldReach(box)) return false;
    final reachM = radiusKm * _metresPerKm + _edgeToleranceM;
    for (var i = 1; i < points.length; i++) {
      final metres = segmentDistanceM(pin, points[i - 1], points[i], distance);
      if (metres <= reachM) return true;
    }
    return false;
  }

  /// Whether [box], grown by the radius, contains the pin. Cheap rejection
  /// of far rides before any segment is measured or an outline is decoded.
  bool couldReach(OutlineBounds box) {
    final dLat = radiusKm / _kmPerDegreeLat * _boundsMargin;
    final widest = math.max(box.south.abs(), box.north.abs()) + dLat;
    final cosLat = math.cos(math.min(widest, _maxLatitude) * _radiansPerDegree);
    final dLng = dLat / math.max(cosLat, _minCosLatitude);
    return pin.lat >= box.south - dLat &&
        pin.lat <= box.north + dLat &&
        withinLongitudes(pin.lng, box.west - dLng, box.east + dLng);
  }

  /// Fewer points than this make no segment, so nothing can come near.
  static const _minPointsForLine = 2;

  static const _metresPerKm = 1000.0;
  static const _radiansPerDegree = math.pi / 180;

  /// The sphere of the shared [HaversineDistanceCalculator].
  static const _earthRadiusKm = 6371.0;
  static const _kmPerDegreeLat = _earthRadiusKm * _radiansPerDegree;

  /// Safety factor on the grown bounds, so the box never rejects a ride the
  /// segment test would accept.
  static const _boundsMargin = 1.05;

  /// Caps on the latitude and its cosine, so the longitude margin stays
  /// finite near the poles.
  static const _maxLatitude = 89.0;
  static const _minCosLatitude = 0.01;

  /// Float noise allowed on a ride that touches the circle exactly.
  static const _edgeToleranceM = 1e-6;

  @override
  bool operator ==(Object other) =>
      other is AreaFilter && other.pin == pin && other.radiusKm == radiusKm;

  @override
  int get hashCode => Object.hash(pin, radiusKm);
}
