import '../data/db/ride_with_trackpoints.dart';
import 'distance_calculator.dart';
import 'ride_stats.dart';

/// Aggregated stats for a set of rides (the "This week"/day/year hero card).
/// Mirrors the original Kotlin `WeeklyStats`.
class WeeklyStats {
  const WeeklyStats({
    required this.totalKm,
    required this.rideCount,
    required this.avgSpeedKmh,
    required this.totalDurationSeconds,
  });

  const WeeklyStats.zero()
      : totalKm = 0.0,
        rideCount = 0,
        avgSpeedKmh = 0.0,
        totalDurationSeconds = 0;

  final double totalKm;
  final int rideCount;
  final double avgSpeedKmh;
  final int totalDurationSeconds;
}

/// Aggregates per-ride stats into [WeeklyStats] — reused for week/day/year,
/// matching the identical HomeViewModel blocks. Empty input → all zeros.
WeeklyStats aggregateStats(
    List<RideWithTrackpoints> rides, DistanceCalculator calc) {
  final stats = rides.map((r) => computeRideStats(r, calc)).toList();
  final totalDistanceMetres =
      stats.fold<double>(0.0, (sum, s) => sum + s.distanceMetres);
  final totalDurationMs = stats.fold<int>(0, (sum, s) => sum + s.durationMs);
  final totalKm = totalDistanceMetres / 1000.0;

  return WeeklyStats(
    totalKm: totalKm,
    rideCount: rides.length,
    avgSpeedKmh:
        totalDurationMs > 0 ? totalKm / (totalDurationMs / 3600000.0) : 0.0,
    totalDurationSeconds: totalDurationMs ~/ 1000,
  );
}
