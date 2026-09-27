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
    test('north-north-west → ≈ 337.5°, in the wrap region below 360', () {
      // At the equator a tiny step's bearing is atan2(dLng, dLat).
      expect(
          bearingDegrees((lat: 0.0, lng: 0.0),
              (lat: 0.00092388, lng: -0.00038268)),
          closeTo(337.5, 0.01));
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
    test('no current position → full body, no tail', () {
      const a = (lat: 52.0, lng: 13.0);
      const b = (lat: 52.001, lng: 13.0);
      final split = splitRouteTail(const [a, b], null);
      expect(split.body, [a, b]);
      expect(split.tailStart, isNull);
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

  group('nextHeading', () {
    test('no anchor yet → the point becomes the anchor, bearing unchanged',
        () {
      const p = (lat: 52.0, lng: 13.0);
      final next = nextHeading((anchor: null, bearing: null), p);
      expect(next.anchor, p);
      expect(next.bearing, isNull);
    });
    test('moved less than minMetres (10 m) → state unchanged', () {
      const anchor = (lat: 52.0, lng: 13.0);
      // ~6.9 m east — over travelBearing's own 5 m, under nextHeading's 10 m.
      final next = nextHeading(
          (anchor: anchor, bearing: 42.0), (lat: 52.0, lng: 13.0001));
      expect(next.anchor, anchor);
      expect(next.bearing, 42.0);
    });
    test(
        'moved at least minMetres with no bearing yet → bearing = travel '
        'direction (east → 90°), anchor moves to the point', () {
      const anchor = (lat: 52.0, lng: 13.0);
      const moved = (lat: 52.0, lng: 13.0002); // ~13.7 m east
      final next = nextHeading((anchor: anchor, bearing: null), moved);
      expect(next.anchor, moved);
      expect(next.bearing, closeTo(90, 0.01));
    });
    test(
        'moved far enough but turned less than minTurnDegrees (10°) → anchor '
        'moves, bearing kept', () {
      // Equator: ~22 m east with a slight southward drift ≈ 95°.
      const anchor = (lat: 0.0, lng: 0.0);
      const moved = (lat: -0.0000175, lng: 0.0002);
      final next = nextHeading((anchor: anchor, bearing: 90.0), moved);
      expect(next.anchor, moved);
      expect(next.bearing, 90.0);
    });
    test('turned at least minTurnDegrees → new bearing (90° → 180°)', () {
      const anchor = (lat: 52.0, lng: 13.0);
      const south = (lat: 51.9998, lng: 13.0); // ~22 m south
      final next = nextHeading((anchor: anchor, bearing: 90.0), south);
      expect(next.bearing, closeTo(180, 0.01));
    });
    test(
        'turn across north is wrap-aware: 358° → ≈ 3° is a ≈ 5° turn, so the '
        'bearing is kept', () {
      // Equator: ~22 m north with a slight eastward drift ≈ 3°.
      const anchor = (lat: 0.0, lng: 0.0);
      const moved = (lat: 0.0002, lng: 0.0000105);
      final next = nextHeading((anchor: anchor, bearing: 358.0), moved);
      expect(next.bearing, 358.0);
    });
  });
}
