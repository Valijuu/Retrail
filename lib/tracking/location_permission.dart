import 'package:geolocator/geolocator.dart';

/// What `startRide()` should do given the current permission + location-services
/// state. Pure, so the branching (ported from the original `MapPage` flow) is
/// unit-tested without the platform.
enum LocationStartAction {
  /// Permission granted and GPS on → start the source + service + tracker.
  proceed,

  /// Permission not yet decided → ask for it.
  requestPermission,

  /// Granted, but device location services are off → prompt to turn them on.
  openLocationSettings,

  /// Permanently denied → show the rationale dialog with an app-settings path.
  showRationale,
}

/// Resolves permission FIRST, then the GPS-on check (only when granted) —
/// mirroring the original: request location permission, then check that location
/// services are enabled before recording.
LocationStartAction permissionGateDecision({
  required bool serviceEnabled,
  required LocationPermission permission,
}) {
  switch (permission) {
    case LocationPermission.denied:
    case LocationPermission.unableToDetermine:
      return LocationStartAction.requestPermission;
    case LocationPermission.deniedForever:
      return LocationStartAction.showRationale;
    case LocationPermission.whileInUse:
    case LocationPermission.always:
      return serviceEnabled
          ? LocationStartAction.proceed
          : LocationStartAction.openLocationSettings;
  }
}
