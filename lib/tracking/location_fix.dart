/// A platform-agnostic GPS fix consumed by [RideTracker]'s filter. Decouples the
/// recording pipeline from `geolocator`.
///
/// [elapsedRealtimeNanos] is a **monotonic** clock reading (like Android's
/// `Location.getElapsedRealtimeNanos`), synthesized at ingestion in the platform
/// layer — used only for relative timing in the freshness/outlier filters.
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
