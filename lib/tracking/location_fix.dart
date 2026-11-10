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
    this.altitude,
    this.altitudeAccuracy,
  });

  /// Worst vertical accuracy, in metres, at which an altitude is still kept.
  static const maxAltitudeAccuracyM = 25.0;

  final double latitude;
  final double longitude;
  final double accuracy;
  final bool hasSpeed;
  final double speed; // m/s
  final int elapsedRealtimeNanos;

  /// Platform altitude in metres as reported, or null when there is none.
  final double? altitude;

  /// Vertical accuracy in metres; null or `0` means the platform gave none.
  final double? altitudeAccuracy;

  /// The altitude to record (#97): the platform altitude when it is valid, else
  /// null. Invalid is a non-finite value, a vertical accuracy worse than
  /// [maxAltitudeAccuracyM], or exactly `0` with unknown accuracy (the
  /// placeholder Android reports when it has no altitude). Never decides
  /// whether the fix itself is recorded.
  double? get recordedAltitude {
    final altitude = this.altitude;
    if (altitude == null || !altitude.isFinite) return null;
    final accuracy = altitudeAccuracy;
    final accuracyKnown = accuracy != null && accuracy > 0;
    if (!accuracyKnown) return altitude == 0 ? null : altitude;
    return accuracy > maxAltitudeAccuracyM ? null : altitude;
  }
}
