import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/heading.dart' show LatLng;
import 'outline_fill.dart';

/// What the my-location button found out (#96).
sealed class LocateResult {
  const LocateResult();
}

/// Allowed: the position, and the position stream may start.
class Located extends LocateResult {
  const Located(this.position);
  final LatLng position;
}

/// Not allowed (this time).
class LocateDenied extends LocateResult {
  const LocateDenied();
}

/// Denied for good: only the app settings can allow it.
class LocateBlocked extends LocateResult {
  const LocateBlocked();
}

/// The device's location services are off.
class LocateServicesOff extends LocateResult {
  const LocateServicesOff();
}

/// Allowed, but no position came in time (indoors, no sky) (#120).
class LocateNoFix extends LocateResult {
  const LocateNoFix();
}

/// The map's access to the device position. Asks for location while the app
/// is in use only; never for Always, never for notifications.
abstract interface class MapLocator {
  Future<LocateResult> locate();

  /// Positions while subscribed; the caller subscribes only while the map is
  /// visible and the app is in front.
  Stream<LatLng> positions();

  Future<void> openAppSettings();

  /// The device's location settings, to switch the services on (#120).
  Future<void> openLocationSettings();
}

/// Production [MapLocator] over `geolocator`.
class GeolocatorMapLocator implements MapLocator {
  const GeolocatorMapLocator();

  /// Moving less than this, in metres, gives no new position.
  static const int _distanceFilterM = 5;

  /// How long the my-location button waits for a fix.
  static const Duration _fixTimeout = Duration(seconds: 10);

  @override
  Future<LocateResult> locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocateServicesOff();
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    switch (permission) {
      case LocationPermission.deniedForever:
        return const LocateBlocked();
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return const LocateDenied();
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        try {
          final p = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(timeLimit: _fixTimeout),
          );
          return Located((lat: p.latitude, lng: p.longitude));
        } on Exception {
          // No fix in time, or the platform failed to give one (#120).
          return const LocateNoFix();
        }
    }
  }

  @override
  Stream<LatLng> positions() => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(distanceFilter: _distanceFilterM),
  ).map((p) => (lat: p.latitude, lng: p.longitude));

  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}

final mapLocatorProvider = Provider<MapLocator>(
  (ref) => const GeolocatorMapLocator(),
);

/// The latest position, kept only after the rider allowed location with the
/// button.
class MapPositionNotifier extends Notifier<LatLng?> {
  @override
  LatLng? build() => null;

  void set(LatLng? position) => state = position;
}

final mapPositionProvider = NotifierProvider<MapPositionNotifier, LatLng?>(
  MapPositionNotifier.new,
);

/// Whether the rider allowed location through the button this session.
class LocationEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void enable() => state = true;

  /// The position stream failed (services off, permission withdrawn): the
  /// button has to ask again (#110).
  void lose() => state = false;
}

final locationEnabledProvider = NotifierProvider<LocationEnabledNotifier, bool>(
  LocationEnabledNotifier.new,
);

/// Keeps [mapPositionProvider] current while location is allowed, the map is
/// visible and the app is in front; the stream is closed otherwise. A stream
/// error drops the stale position and the permission of this session, so the
/// map shows no old position and the view can show the location hint (#110).
final positionFeedProvider = Provider<void>((ref) {
  final active =
      ref.watch(locationEnabledProvider) &&
      ref.watch(mapVisibleProvider) &&
      ref.watch(appForegroundProvider);
  if (!active) return;
  final position = ref.read(mapPositionProvider.notifier);
  final enabled = ref.read(locationEnabledProvider.notifier);
  final sub = ref
      .read(mapLocatorProvider)
      .positions()
      .listen(
        position.set,
        onError: (Object _) {
          position.set(null);
          enabled.lose();
        },
        cancelOnError: true,
      );
  ref.onDispose(sub.cancel);
});
