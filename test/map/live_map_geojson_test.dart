import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/route_progress.dart';
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

  group('referenceGeoJson', () {
    final track = RouteTrack(const [
      (lat: 48.0, lng: 11.0),
      (lat: 48.001, lng: 11.0),
      (lat: 48.002, lng: 11.0),
    ]);

    test('no progress yet: everything ahead, nothing done', () {
      final g = referenceGeoJson(track, null);
      expect((jsonDecode(g.done) as Map)['type'], 'FeatureCollection');
      final ahead = jsonDecode(g.ahead) as Map<String, dynamic>;
      expect((ahead['geometry']['coordinates'] as List).length, 3);
    });

    test('mid-route: done and ahead meet at the cut', () {
      final g = referenceGeoJson(track, track.lengthM / 4);
      final done = jsonDecode(g.done) as Map<String, dynamic>;
      final ahead = jsonDecode(g.ahead) as Map<String, dynamic>;
      expect((done['geometry']['coordinates'] as List).last,
          (ahead['geometry']['coordinates'] as List).first);
    });
  });

  group('referencePushTarget', () {
    final a = RouteTrack(const [(lat: 48.0, lng: 11.0), (lat: 48.001, lng: 11.0)]);
    final b = RouteTrack(const [(lat: 49.0, lng: 11.0), (lat: 49.001, lng: 11.0)]);

    test('no reference sources in this style load: never push', () {
      expect(referencePushTarget(drawn: null, current: null), isNull);
      expect(referencePushTarget(drawn: null, current: a), isNull);
    });

    test('the drawn reference is still current: push it', () {
      expect(referencePushTarget(drawn: a, current: a), same(a));
    });

    test('a different reference replaces the drawn one: push the new one', () {
      expect(referencePushTarget(drawn: a, current: b), same(b));
    });

    test('the reference went away: push nothing', () {
      expect(referencePushTarget(drawn: a, current: null), isNull);
    });
  });
}
