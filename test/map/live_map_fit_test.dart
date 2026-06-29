import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:retrail/map/live_map.dart';
import 'package:retrail/map/preview_projection.dart';

void main() {
  group('routeBounds', () {
    test('null for an empty route (nothing to fit)', () {
      expect(routeBounds(const []), isNull);
    });

    test('encloses every point of the route', () {
      const points = <RoutePoint>[
        (lat: 49.40, lng: 11.05),
        (lat: 49.46, lng: 11.12),
        (lat: 49.42, lng: 11.02), // westmost
        (lat: 49.47, lng: 11.09), // northmost
      ];
      final b = routeBounds(points)!;
      for (final p in points) {
        expect(b.contains(LatLng(p.lat, p.lng)), isTrue,
            reason: 'point ($p) must be inside the fitted bounds');
      }
    });

    test('a single point yields a degenerate but valid bounds', () {
      final b = routeBounds(const [(lat: 49.4, lng: 11.0)])!;
      expect(b.contains(const LatLng(49.4, 11.0)), isTrue);
    });
  });
}
