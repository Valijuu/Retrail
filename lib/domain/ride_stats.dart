import 'dart:math' as math;

import '../data/db/app_database.dart' show Ride;
import '../data/db/ride_with_trackpoints.dart';
import 'distance_calculator.dart';

/// Computed statistics for a single ride. Mirrors the original Kotlin
/// `RideStats` (durations in ms, distance in metres, speeds in km/h).
class RideStats {
  const RideStats({
    required this.durationMs,
    required this.distanceMetres,
    required this.maxSpeedKmh,
    required this.avgSpeedKmh,
  });

  final int durationMs;
  final double distanceMetres;
  final double maxSpeedKmh;
  final double avgSpeedKmh;
}

/// Replicates the original `computeRideStats` exactly:
/// - duration = endTime - startTime when both present, else 0
/// - distance = sum of haversine over consecutive trackpoints
/// - maxSpeed = max provider speed (m/s) × 3.6, else 0
/// - avgSpeed = km / hours when duration > 0, else 0
RideStats computeRideStats(RideWithTrackpoints rwt, DistanceCalculator calc) {
  final ride = rwt.ride;
  final trackpoints = rwt.trackpoints;

  final durationMs = (ride.startTime != null && ride.endTime != null)
      ? ride.endTime! - ride.startTime!
      : 0;

  var distanceMetres = 0.0;
  for (var i = 1; i < trackpoints.length; i++) {
    distanceMetres += calc.distanceBetween(
      trackpoints[i - 1].latitude,
      trackpoints[i - 1].longitude,
      trackpoints[i].latitude,
      trackpoints[i].longitude,
    );
  }

  final speeds = trackpoints.map((t) => t.speed).whereType<double>();
  final maxSpeedKmh = speeds.isEmpty ? 0.0 : speeds.reduce(math.max) * 3.6;

  final avgSpeedKmh =
      durationMs > 0 ? (distanceMetres / 1000.0 / (durationMs / 3600000.0)) : 0.0;

  return RideStats(
    durationMs: durationMs,
    distanceMetres: distanceMetres,
    maxSpeedKmh: maxSpeedKmh,
    avgSpeedKmh: avgSpeedKmh,
  );
}

/// Reads the [RideStats] denormalized onto [ride] at finalization time (see
/// `RideRepository.updateEndTime`) — null when not yet computed (an
/// in-progress ride, or a pre-migration row before the backfill ran), so
/// callers know to fall back to [computeRideStats].
RideStats? storedRideStats(Ride ride) {
  final distanceMetres = ride.distanceMetres;
  final durationMs = ride.durationMs;
  final avgSpeedKmh = ride.avgSpeedKmh;
  final maxSpeedKmh = ride.maxSpeedKmh;
  if (distanceMetres == null ||
      durationMs == null ||
      avgSpeedKmh == null ||
      maxSpeedKmh == null) {
    return null;
  }
  return RideStats(
    durationMs: durationMs,
    distanceMetres: distanceMetres,
    maxSpeedKmh: maxSpeedKmh,
    avgSpeedKmh: avgSpeedKmh,
  );
}
