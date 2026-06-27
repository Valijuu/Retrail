import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:retrail/tracking/location_permission.dart';

void main() {
  group('permissionGateDecision', () {
    test('denied / undetermined → request permission', () {
      for (final p in [
        LocationPermission.denied,
        LocationPermission.unableToDetermine,
      ]) {
        expect(
          permissionGateDecision(serviceEnabled: true, permission: p),
          LocationStartAction.requestPermission,
        );
      }
    });

    test('deniedForever → show rationale (settings)', () {
      expect(
        permissionGateDecision(
          serviceEnabled: true,
          permission: LocationPermission.deniedForever,
        ),
        LocationStartAction.showRationale,
      );
    });

    test('granted + services on → proceed', () {
      for (final p in [
        LocationPermission.whileInUse,
        LocationPermission.always,
      ]) {
        expect(
          permissionGateDecision(serviceEnabled: true, permission: p),
          LocationStartAction.proceed,
        );
      }
    });

    test('granted but location services off → open location settings', () {
      expect(
        permissionGateDecision(
          serviceEnabled: false,
          permission: LocationPermission.whileInUse,
        ),
        LocationStartAction.openLocationSettings,
      );
    });

    test('permission is resolved before the services-on check', () {
      // Even with services off, an unresolved permission is requested first
      // (mirrors the original: request permission, THEN check GPS settings).
      expect(
        permissionGateDecision(
          serviceEnabled: false,
          permission: LocationPermission.denied,
        ),
        LocationStartAction.requestPermission,
      );
    });
  });
}
