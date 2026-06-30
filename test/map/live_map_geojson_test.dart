import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/map/live_map.dart';
import 'package:retrail/map/preview_projection.dart';

void main() {
  group('routeLineGeoJson', () {
    test('emits a LineString in lng,lat order', () {
      const pts = <RoutePoint>[(lat: 49.44, lng: 11.08), (lat: 49.45, lng: 11.10)];
      final f = jsonDecode(routeLineGeoJson(pts)) as Map<String, dynamic>;
      expect(f['type'], 'Feature');
      expect(f['geometry']['type'], 'LineString');
      final coords = f['geometry']['coordinates'] as List;
      expect(coords.first, [11.08, 49.44]); // [lng, lat]
      expect(coords.length, 2);
    });
    test('a route with <2 points yields an empty FeatureCollection', () {
      // MapLibre rejects a LineString with fewer than two coordinates
      // ("A line string must have two or more coordinate points"), so a
      // just-started ride (0 or 1 fix) must emit an empty document instead.
      for (final pts in <List<RoutePoint>>[
        const [],
        const [(lat: 49.44, lng: 11.08)],
      ]) {
        final f = jsonDecode(routeLineGeoJson(pts)) as Map<String, dynamic>;
        expect(f['type'], 'FeatureCollection');
        expect(f['features'], isEmpty);
      }
    });
  });
}
