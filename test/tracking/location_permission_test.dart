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

    test(
        'granted + services on but only APPROXIMATE location → ask for '
        'precise (issue #28: coarse fixes never pass the accuracy filter)', () {
      for (final p in [
        LocationPermission.whileInUse,
        LocationPermission.always,
      ]) {
        expect(
          permissionGateDecision(
              serviceEnabled: true, permission: p, precise: false),
          LocationStartAction.requestPreciseLocation,
        );
      }
    });

    test('services off wins over approximate accuracy', () {
      expect(
        permissionGateDecision(
          serviceEnabled: false,
          permission: LocationPermission.whileInUse,
          precise: false,
        ),
        LocationStartAction.openLocationSettings,
      );
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

    // iOS reports every app as denied while Location Services are off
    // globally (CLAuthorizationStatus.denied → geolocator deniedForever), so
    // there a denial can't be told apart from services being off.
    group('servicesOffReportsDenied (iOS)', () {
      test('services off + deniedForever → open location settings', () {
        expect(
          permissionGateDecision(
            serviceEnabled: false,
            permission: LocationPermission.deniedForever,
            servicesOffReportsDenied: true,
          ),
          LocationStartAction.openLocationSettings,
        );
      });
      test('services on + deniedForever → still show rationale', () {
        expect(
          permissionGateDecision(
            serviceEnabled: true,
            permission: LocationPermission.deniedForever,
            servicesOffReportsDenied: true,
          ),
          LocationStartAction.showRationale,
        );
      });
      test(
          'services off + denied / undetermined → open location settings — '
          'iOS cannot grant while services are off, so the request would '
          'never resolve', () {
        for (final p in [
          LocationPermission.denied,
          LocationPermission.unableToDetermine,
        ]) {
          expect(
            permissionGateDecision(
              serviceEnabled: false,
              permission: p,
              servicesOffReportsDenied: true,
            ),
            LocationStartAction.openLocationSettings,
          );
        }
      });
      test(
          'without the flag (Android) services off + deniedForever → show '
          'rationale, original order unchanged', () {
        expect(
          permissionGateDecision(
            serviceEnabled: false,
            permission: LocationPermission.deniedForever,
          ),
          LocationStartAction.showRationale,
        );
      });
    });
  });
}
