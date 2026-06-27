import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:retrail/tracking/location_source.dart';

Position _pos({
  required DateTime timestamp,
  double speed = 0,
  double speedAccuracy = 0,
  double accuracy = 5,
}) =>
    Position(
      longitude: 13.0,
      latitude: 52.0,
      timestamp: timestamp,
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: speed,
      speedAccuracy: speedAccuracy,
    );

void main() {
  group('fixFromPosition', () {
    test('carries the real capture time as nanoseconds (not now)', () {
      final ts = DateTime.fromMicrosecondsSinceEpoch(1700000000123456);
      final fix = fixFromPosition(_pos(timestamp: ts));
      // ns == microsecondsSinceEpoch * 1000 — the freshness filter depends on
      // this being the fix's OWN capture time, not a clock read at ingestion.
      expect(fix.elapsedRealtimeNanos, 1700000000123456 * 1000);
    });

    test('passes through lat/lng/accuracy', () {
      final fix = fixFromPosition(_pos(timestamp: DateTime(2024), accuracy: 12));
      expect(fix.latitude, 52.0);
      expect(fix.longitude, 13.0);
      expect(fix.accuracy, 12);
    });

    test('hasSpeed true only when the platform reports a valid speed', () {
      // Valid: positive speedAccuracy (Android) / non-negative speed (iOS).
      final valid = fixFromPosition(
        _pos(timestamp: DateTime(2024), speed: 5, speedAccuracy: 1),
      );
      expect(valid.hasSpeed, isTrue);
      expect(valid.speed, 5);
    });

    test('hasSpeed false when speed is invalid (iOS -1 / Android no-accuracy)',
        () {
      final iosInvalid = fixFromPosition(
        _pos(timestamp: DateTime(2024), speed: -1, speedAccuracy: -1),
      );
      expect(iosInvalid.hasSpeed, isFalse);

      // Android "no speed": speed 0 with zero accuracy must NOT count as a real
      // 0 km/h reading, or the stationary guard would drop valid start fixes.
      final androidNoSpeed = fixFromPosition(
        _pos(timestamp: DateTime(2024), speed: 0, speedAccuracy: 0),
      );
      expect(androidNoSpeed.hasSpeed, isFalse);
    });
  });
}
