import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/route_markers.dart';
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

    test('nothing ridden: done is empty, ahead is the whole track', () {
      final g = referenceGeoJson(track, null);
      final done = jsonDecode(g.done) as Map<String, dynamic>;
      expect(done['type'], 'FeatureCollection');
      expect(done['features'], isEmpty);
      final ahead = jsonDecode(g.ahead) as Map<String, dynamic>;
      expect((ahead['geometry']['coordinates'] as List).length, 3);
    });

    test('one ridden segment: a MultiLineString of it, ahead stays whole', () {
      final g = referenceGeoJson(track, [
        [track.points[0], track.points[1]],
      ]);
      final done = jsonDecode(g.done) as Map<String, dynamic>;
      expect(done['geometry']['type'], 'MultiLineString');
      final lines = done['geometry']['coordinates'] as List;
      expect(lines.length, 1);
      expect((lines.single as List).length, 2);
      expect((lines.single as List).first, [11.0, 48.0]); // [lng, lat]
      final ahead = jsonDecode(g.ahead) as Map<String, dynamic>;
      expect((ahead['geometry']['coordinates'] as List).length, 3);
    });

    test('two ridden segments (a loop across its seam): both drawn', () {
      final g = referenceGeoJson(track, [
        [track.points[0], track.points[1]],
        [track.points[1], track.points[2]],
      ]);
      final done = jsonDecode(g.done) as Map<String, dynamic>;
      final lines = done['geometry']['coordinates'] as List;
      expect(lines.length, 2);
      expect((lines[1] as List).last, [11.0, 48.002]);
    });

    test('segments with fewer than 2 points are dropped', () {
      final g = referenceGeoJson(track, [
        [track.points[0]],
        [track.points[1], track.points[2]],
      ]);
      final done = jsonDecode(g.done) as Map<String, dynamic>;
      expect((done['geometry']['coordinates'] as List).length, 1);
      final none = jsonDecode(referenceGeoJson(track, <List<RoutePoint>>[
        const [],
        [track.points[0]],
      ]).done) as Map<String, dynamic>;
      expect(none['type'], 'FeatureCollection');
      expect(none['features'], isEmpty);
    });
  });

  group('referenceMarkerPoints', () {
    const pts = <RoutePoint>[
      (lat: 48.0, lng: 11.0),
      (lat: 48.001, lng: 11.0),
      (lat: 48.002, lng: 11.0),
    ];

    test('open: start at the first point, finish at the last', () {
      final m = referenceMarkerPoints(RouteEndpointStyle.open, pts);
      expect(m.start, pts.first);
      expect(m.end, pts.last);
    });

    test('a flip swaps them: the reversed points move both markers', () {
      final m = referenceMarkerPoints(
          RouteEndpointStyle.open, pts.reversed.toList());
      expect(m.start, pts.last);
      expect(m.end, pts.first);
    });

    test('loop: one combined marker at the start, no finish', () {
      final m = referenceMarkerPoints(RouteEndpointStyle.loop, pts);
      expect(m.start, pts.first);
      expect(m.end, isNull);
    });

    test('startOnly: the start marker only', () {
      final m = referenceMarkerPoints(
          RouteEndpointStyle.startOnly, const [(lat: 48.0, lng: 11.0)]);
      expect(m.start, (lat: 48.0, lng: 11.0));
      expect(m.end, isNull);
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

  group('referenceUpdateGeoJson', () {
    final a = RouteTrack(const [(lat: 48.0, lng: 11.0), (lat: 48.001, lng: 11.0)]);
    final b = RouteTrack(const [(lat: 49.0, lng: 11.0), (lat: 49.001, lng: 11.0)]);
    final done = [
      [a.points[0], a.points[1]],
    ];

    test('nothing pushed yet: the whole line and the ridden parts', () {
      final g = referenceUpdateGeoJson(a, done, lastPushed: null);
      expect(g.ahead, referenceGeoJson(a, done).ahead);
      expect(g.done, referenceGeoJson(a, done).done);
    });

    test('the same reference already pushed: only the ridden parts', () {
      final g = referenceUpdateGeoJson(a, done, lastPushed: a);
      expect(g.ahead, isNull);
      expect(g.done, referenceGeoJson(a, done).done);
    });

    test('a replaced reference (a flip): the new whole line', () {
      final g = referenceUpdateGeoJson(b, null, lastPushed: a);
      expect(g.ahead, referenceGeoJson(b, null).ahead);
    });
  });
}
