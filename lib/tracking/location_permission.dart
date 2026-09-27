import 'package:geolocator/geolocator.dart';

/// What `startRide()` should do given the current permission + location-services
/// state. Pure, so the branching (ported from the original `MapPage` flow) is
/// unit-tested without the platform.
enum LocationStartAction {
  /// Permission granted and GPS on → start the source + service + tracker.
  proceed,

  /// Permission not yet decided → ask for it.
  requestPermission,

  /// Device location services are off → prompt to turn them on. On iOS reached
  /// whenever services are off, whatever the permission; on Android only once
  /// permission is granted.
  openLocationSettings,

  /// Permanently denied → show the rationale dialog with an app-settings path.
  showRationale,

  /// Granted and GPS on, but only APPROXIMATE location (Android 12+ "Approximate",
  /// iOS "Precise: Off") → ask for precise. Coarse fixes are hundreds of metres
  /// off and never pass the recording accuracy filter, so the ride would record
  /// nothing without saying so (issue #28).
  requestPreciseLocation,
}

/// Where [servicesOffReportsDenied] (iOS), services off ALWAYS resolves to
/// [LocationStartAction.openLocationSettings], checked before the permission:
/// while Location Services are off globally, iOS reports every app as denied
/// and no permission can be granted (the request would never resolve), so the
/// reported permission is meaningless until services are back on.
///
/// Otherwise (Android, false) permission is resolved FIRST, then the GPS-on
/// check once granted — mirroring the original: request location permission,
/// then check that location services are enabled before recording. A
/// permanent denial always shows the rationale.
///
/// A grant with services on is finally checked for PRECISE location
/// ([precise]).
LocationStartAction permissionGateDecision({
  required bool serviceEnabled,
  required LocationPermission permission,
  bool precise = true,
  bool servicesOffReportsDenied = false,
}) {
  if (servicesOffReportsDenied && !serviceEnabled) {
    return LocationStartAction.openLocationSettings;
  }
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
