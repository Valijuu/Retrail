import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart';

import 'location_fix.dart';

/// A stream of GPS fixes feeding [RideTracker.onLocationReceived]. An interface
/// so the recording wiring can be driven by a fake in tests without the platform.
abstract interface class LocationSource {
  /// High-accuracy fixes (~1 s cadence) for the lifetime of the subscription.
  Stream<LocationFix> get fixes;

  /// Last known fix, to seed an immediate marker so the map isn't blank.
  Future<LocationFix?> lastKnown();

  /// Emits whenever the device's location services are switched on (true) or
  /// off (false) — while off, [fixes] stays silent (issue #33).
  Stream<bool> get serviceEnabled;
}

/// Maps a geolocator [Position] to a [LocationFix].
///
/// **`elapsedRealtimeNanos` is the fix's own capture time** (`Position.timestamp`
/// in ns), never a clock read at ingestion — the stage-0 freshness filter
/// compares it against "now", so a stale cached fix must carry its old time.
///
/// geolocator drops Android's `hasSpeed()` flag, so we reconstruct it:
/// `hasSpeed` is true only when the platform reports a *valid* speed — a
/// non-negative speed with positive speed accuracy. This treats iOS's `-1`
/// (invalid) and Android's accuracy-less `0` as "no speed", so the tracker's
/// stationary guard doesn't drop valid fixes at ride start.
LocationFix fixFromPosition(Position p) => LocationFix(
      latitude: p.latitude,
      longitude: p.longitude,
      accuracy: p.accuracy,
      hasSpeed: p.speed >= 0 && p.speedAccuracy > 0,
      speed: p.speed,
      elapsedRealtimeNanos: p.timestamp.microsecondsSinceEpoch * 1000,
    );

/// Production [LocationSource] over `geolocator`.
class GeolocatorLocationSource implements LocationSource {
  const GeolocatorLocationSource();

  @override
  Stream<LocationFix> get fixes =>
      Geolocator.getPositionStream(locationSettings: _settings())
          .map(fixFromPosition);

  @override
  Stream<bool> get serviceEnabled => Geolocator.getServiceStatusStream()
      .map((status) => status == ServiceStatus.enabled);

  @override
  Future<LocationFix?> lastKnown() async {
    final p = await Geolocator.getLastKnownPosition();
    return p == null ? null : fixFromPosition(p);
  }

  // High accuracy, ~1 s cadence, no distance filter — mirrors the original
  // FusedLocation PRIORITY_HIGH_ACCURACY @ 1 s. Background keep-alive on Android
  // is the flutter_foreground_task service (not geolocator's own notification);
  // iOS records in the background via these Apple settings.
  LocationSettings _settings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 1),
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        activityType: ActivityType.otherNavigation,
        allowBackgroundLocationUpdates: true,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );
  }
}
