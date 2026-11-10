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

/// The map's access to the device position. Asks for location while the app
/// is in use only; never for Always, never for notifications.
abstract interface class MapLocator {
  Future<LocateResult> locate();

  /// Positions while subscribed; the caller subscribes only while the map is
  /// visible and the app is in front.
  Stream<LatLng> positions();

  Future<void> openAppSettings();
}

/// Production [MapLocator] over `geolocator`.
class GeolocatorMapLocator implements MapLocator {
  const GeolocatorMapLocator();

  /// Moving less than this, in metres, gives no new position.
  static const int _distanceFilterM = 5;

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
        final p = await Geolocator.getCurrentPosition();
        return Located((lat: p.latitude, lng: p.longitude));
    }
  }

  @override
  Stream<LatLng> positions() => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(distanceFilter: _distanceFilterM),
  ).map((p) => (lat: p.latitude, lng: p.longitude));

  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();
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
}

final locationEnabledProvider = NotifierProvider<LocationEnabledNotifier, bool>(
  LocationEnabledNotifier.new,
);

/// Keeps [mapPositionProvider] current while location is allowed, the map is
/// visible and the app is in front; the stream is closed otherwise.
final positionFeedProvider = Provider<void>((ref) {
  final active =
      ref.watch(locationEnabledProvider) &&
      ref.watch(mapVisibleProvider) &&
      ref.watch(appForegroundProvider);
  if (!active) return;
  final sub = ref
      .read(mapLocatorProvider)
      .positions()
      .listen(ref.read(mapPositionProvider.notifier).set);
  ref.onDispose(sub.cancel);
});
