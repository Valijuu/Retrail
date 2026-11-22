import 'dart:math' as math;

import 'geo_constants.dart';

/// Computes the great-circle distance between two coordinates, in meters.
/// Interface seam so tests can inject a fake (the original Android app used an
/// interface here too, backed by `Location.distanceBetween`).
abstract interface class DistanceCalculator {
  double distanceBetween(double lat1, double lon1, double lat2, double lon2);
}

/// Standard Haversine implementation (Earth radius [earthRadiusM]). Differs from the
/// original WGS84 geodesic by <0.5% — imperceptible at displayed km precision.
class HaversineDistanceCalculator implements DistanceCalculator {
  const HaversineDistanceCalculator();

  @override
  double distanceBetween(double lat1, double lon1, double lat2, double lon2) {
    final dLat = (lat2 - lat1) * radiansPerDegree;
    final dLon = (lon2 - lon1) * radiansPerDegree;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * radiansPerDegree) *
            math.cos(lat2 * radiansPerDegree) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusM * c;
  }
}
