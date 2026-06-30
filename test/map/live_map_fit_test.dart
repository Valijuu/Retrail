import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre/maplibre.dart';
import 'package:retrail/map/live_map.dart';
import 'package:retrail/map/preview_projection.dart';

bool _encloses(LngLatBounds b, RoutePoint p) =>
    p.lng >= b.longitudeWest &&
    p.lng <= b.longitudeEast &&
    p.lat >= b.latitudeSouth &&
    p.lat <= b.latitudeNorth;

void main() {
  group('routeBounds', () {
    test('null for an empty route (nothing to fit)', () {
      expect(routeBounds(const []), isNull);
    });

    test('encloses every point of the route', () {
      const points = <RoutePoint>[
        (lat: 49.40, lng: 11.05),
        (lat: 49.46, lng: 11.12),
        (lat: 49.42, lng: 11.02),
        (lat: 49.47, lng: 11.09),
      ];
      final b = routeBounds(points)!;
      for (final p in points) {
        expect(_encloses(b, p), isTrue,
            reason: 'point ($p) must be inside the fitted bounds');
      }
    });

    test('a single point yields a degenerate but valid bounds', () {
      final b = routeBounds(const [(lat: 49.4, lng: 11.0)])!;
      expect(_encloses(b, const (lat: 49.4, lng: 11.0)), isTrue);
    });
  });
}
