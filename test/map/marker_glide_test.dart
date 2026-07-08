import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/map/live_map.dart';

void main() {
  group('lerpPoint', () {
    const a = (lat: 49.4400, lng: 11.0800);
    const b = (lat: 49.4410, lng: 11.0820);

    test('t=0 is the start, t=1 is the end', () {
      expect(lerpPoint(a, b, 0), a);
      expect(lerpPoint(a, b, 1), b);
    });

    test('t=0.5 is the geometric midpoint', () {
      final mid = lerpPoint(a, b, 0.5);
      expect(mid.lat, closeTo(49.4405, 1e-9));
      expect(mid.lng, closeTo(11.0810, 1e-9));
    });
  });

  group('markerShouldSnap', () {
    const from = (lat: 49.4400, lng: 11.0800);

    test('a normal per-fix step (~10 m) glides', () {
      // ~10 m north.
      const to = (lat: 49.44009, lng: 11.0800);
      expect(markerShouldSnap(from, to), isFalse);
    });

    test('a GPS jump (~500 m) snaps instead of a slow slide', () {
      // ~500 m north.
      const to = (lat: 49.4445, lng: 11.0800);
      expect(markerShouldSnap(from, to), isTrue);
    });
  });
}
