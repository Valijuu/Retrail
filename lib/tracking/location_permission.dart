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

  /// Granted and GPS on, but only APPROXIMATE location (Android 12+ "Approximate",
  /// iOS "Precise: Off") → ask for precise. Coarse fixes are hundreds of metres
  /// off and never pass the recording accuracy filter, so the ride would record
  /// nothing without saying so (issue #28).
  requestPreciseLocation,
}

/// Resolves permission FIRST, then the GPS-on check (only when granted) —
/// mirroring the original: request location permission, then check that location
/// services are enabled before recording — and finally that the grant is for
/// PRECISE location ([precise]).
LocationStartAction permissionGateDecision({
  required bool serviceEnabled,
  required LocationPermission permission,
  bool precise = true,
}) {
  switch (permission) {
    case LocationPermission.denied:
    case LocationPermission.unableToDetermine:
      return LocationStartAction.requestPermission;
    case LocationPermission.deniedForever:
      return LocationStartAction.showRationale;
    case LocationPermission.whileInUse:
    case LocationPermission.always:
      if (!serviceEnabled) return LocationStartAction.openLocationSettings;
      return precise
          ? LocationStartAction.proceed
          : LocationStartAction.requestPreciseLocation;
  }
}
