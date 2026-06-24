import 'dart:math' as math;

/// Computes the great-circle distance between two coordinates, in meters.
/// Interface seam so tests can inject a fake (the original Android app used an
/// interface here too, backed by `Location.distanceBetween`).
abstract interface class DistanceCalculator {
  double distanceBetween(double lat1, double lon1, double lat2, double lon2);
}

/// Standard Haversine implementation (Earth radius 6371000 m). Differs from the
/// original WGS84 geodesic by <0.5% — imperceptible at displayed km precision.
class HaversineDistanceCalculator implements DistanceCalculator {
  const HaversineDistanceCalculator();

  static const double _earthRadiusMetres = 6371000;

  @override
  double distanceBetween(double lat1, double lon1, double lat2, double lon2) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusMetres * c;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180.0;
}
