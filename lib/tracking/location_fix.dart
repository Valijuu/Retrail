/// A platform-agnostic GPS fix consumed by [RideTracker]'s filter. Decouples the
/// recording pipeline from `geolocator`.
///
/// [elapsedRealtimeNanos] is the fix's **real capture time** in nanoseconds
/// (from geolocator's `Position.timestamp`), NOT a clock read at ingestion.
/// This is essential: the freshness filter compares it against "now", so a
/// minutes-old cached fix must carry its old capture time to be rejected.
/// Used for the freshness check and inter-fix timing (outlier / min-speed).
class LocationFix {
  const LocationFix({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.hasSpeed,
    required this.speed,
    required this.elapsedRealtimeNanos,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final bool hasSpeed;
  final double speed; // m/s
  final int elapsedRealtimeNanos;
}
