import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart';

import 'ride_recording_controller.dart';

/// Production [LocationPermissionService] over `geolocator`.
class GeolocatorPermissionService implements LocationPermissionService {
  const GeolocatorPermissionService();

  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<bool> isPreciseLocation() async =>
      await Geolocator.getLocationAccuracy() == LocationAccuracyStatus.precise;

  /// Purpose key into `NSLocationTemporaryUsageDescriptionDictionary`
  /// (ios/Runner/Info.plist, DE copy in de.lproj/InfoPlist.strings).
  static const _preciseLocationPurposeKey = 'RideTracking';

  @override
  Future<void> requestPreciseLocation() async {
    if (Platform.isIOS) {
      await Geolocator.requestTemporaryFullAccuracy(
          purposeKey: _preciseLocationPurposeKey);
    } else {
      await Geolocator.requestPermission();
    }
  }

  @override
  Future<void> ensureBackgroundPermission() async {
    // Android's location foreground service covers screen-off recording, so
    // whileInUse is enough there. iOS has no foreground service: background
    // delivery requires "Always", a second request that upgrades whileInUse.
    if (!Platform.isIOS) return;
    if (await Geolocator.checkPermission() == LocationPermission.whileInUse) {
      await Geolocator.requestPermission();
    }
  }

  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();
}
