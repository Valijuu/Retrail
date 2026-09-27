import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/heading.dart';

void main() {
  group('bearingDegrees', () {
    test('due north → 0°', () {
      expect(bearingDegrees((lat: 52.0, lng: 13.0), (lat: 52.01, lng: 13.0)),
          closeTo(0, 1e-9));
    });
    test('due east → 90°', () {
      expect(bearingDegrees((lat: 52.0, lng: 13.0), (lat: 52.0, lng: 13.01)),
          closeTo(90, 0.01));
    });
    test('due south → 180°', () {
      expect(bearingDegrees((lat: 52.01, lng: 13.0), (lat: 52.0, lng: 13.0)),
          closeTo(180, 1e-9));
    });
    test('due west → 270°, never negative', () {
      expect(bearingDegrees((lat: 52.0, lng: 13.01), (lat: 52.0, lng: 13.0)),
          closeTo(270, 0.01));
    });
  });

  group('travelBearing', () {
    test('moved less than minMetres (5 m) → null, heading kept', () {
      // ~3.3 m north (0.00003° of latitude).
      expect(travelBearing((lat: 52.0, lng: 13.0), (lat: 52.00003, lng: 13.0)),
          isNull);
    });
    test('moved at least minMetres → bearing anchor → current (east → 90°)',
        () {
      // ~6.9 m east (0.0001° of longitude at 52°N).
      expect(travelBearing((lat: 52.0, lng: 13.0), (lat: 52.0, lng: 13.0001)),
          closeTo(90, 0.01));
    });
    test('a custom minMetres raises the threshold', () {
      expect(
          travelBearing((lat: 52.0, lng: 13.0), (lat: 52.0, lng: 13.0001),
              minMetres: 10),
          isNull);
    });
  });

  group('splitRouteTail', () {
    test('fewer than 2 points → body is the points, no tail', () {
      const only = (lat: 52.0, lng: 13.0);
      final split = splitRouteTail(const [only], only);
      expect(split.body, [only]);
      expect(split.tailStart, isNull);
    });
    test(
        'current is the newest point → body drops it, tail starts at the '
        'second-to-last point', () {
      const a = (lat: 52.0, lng: 13.0);
      const b = (lat: 52.001, lng: 13.0);
      const c = (lat: 52.002, lng: 13.0);
      final split = splitRouteTail(const [a, b, c], c);
      expect(split.body, [a, b]);
      expect(split.tailStart, b);
    });
    test('current is not the newest point (filtered fix) → full body, no tail',
        () {
      const a = (lat: 52.0, lng: 13.0);
      const b = (lat: 52.001, lng: 13.0);
      const filtered = (lat: 52.0015, lng: 13.0005);
      final split = splitRouteTail(const [a, b], filtered);
      expect(split.body, [a, b]);
      expect(split.tailStart, isNull);
    });
  });
}
