import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/activity_type.dart';
import 'package:retrail/domain/ride_outline.dart';
import 'package:retrail/features/history_map/overview_geojson.dart';

String _poly(List<(double, double)> pts) =>
    RideOutline([for (final p in pts) (lat: p.$1, lng: p.$2)]).encode();

void main() {
  final line = _poly([(48.0, 11.0), (48.0, 11.001)]);

  test('a line fragment lists longitude, latitude pairs', () {
    expect(jsonDecode(lineFragment(line)), [
      [11.0, 48.0],
      [11.001, 48.0],
    ]);
  });

  test('a heat fragment lists points about 30 m apart, ends included', () {
    final points = jsonDecode(heatFragment(line)) as List;
    // 0.001 degrees of longitude at 48 N is about 74 m: 0, 30, 60, end.
    expect(points, hasLength(4));
    expect(points.first, [11.0, 48.0]);
    expect(points.last, [11.001, 48.0]);
  });

  test('joined lines are one MultiLineString feature', () {
    final json =
        jsonDecode(linesGeoJson([lineFragment(line), lineFragment(line)]))
            as Map<String, dynamic>;
    final geometry = (json['features'] as List).single['geometry'] as Map;
    expect(geometry['type'], 'MultiLineString');
    expect(geometry['coordinates'], hasLength(2));
  });

  test('no lines are an empty collection', () {
    final json = jsonDecode(linesGeoJson(const [])) as Map<String, dynamic>;
    expect(json['features'], isEmpty);
  });

  test('joined heat points are one MultiPoint feature', () {
    final json =
        jsonDecode(heatGeoJson([heatFragment(line), heatFragment(line)]))
            as Map<String, dynamic>;
    final geometry = (json['features'] as List).single['geometry'] as Map;
    expect(geometry['type'], 'MultiPoint');
    expect(geometry['coordinates'], hasLength(8));
  });

  group('buildOverviewData', () {
    OverviewRide ride(int id, ActivityType type, {String? cachedLine}) =>
        OverviewRide(
          rideId: id,
          typeId: type.id,
          polyline: line,
          lineFragment: cachedLine,
        );

    test('groups lines per type', () {
      final result = buildOverviewData([
        ride(1, ActivityType.longboard),
        ride(2, ActivityType.longboard),
        ride(3, ActivityType.ski),
      ]);
      expect(result.linesByType.keys, {'LONGBOARD', 'SKI'});
      expect(
        jsonDecode(
          result.linesByType['LONGBOARD']!,
        )['features'][0]['geometry']['coordinates'],
        hasLength(2),
      );
    });

    test('a ride without a type is drawn as other', () {
      final result = buildOverviewData([
        OverviewRide(rideId: 1, typeId: null, polyline: line),
      ]);
      expect(result.linesByType.keys, ['OTHER']);
    });

    test('returns the new fragments and reuses the cached ones', () {
      final result = buildOverviewData([
        ride(1, ActivityType.longboard),
        ride(2, ActivityType.longboard, cachedLine: '[[1,2],[3,4]]'),
      ]);
      expect(result.newLineFragments.keys, [1]);
      expect(result.linesByType['LONGBOARD'], contains('[[1,2],[3,4]]'));
    });

    test('the heat collection joins the heat points of all rides', () {
      final result = buildOverviewData([
        ride(1, ActivityType.ski),
        ride(2, ActivityType.ski),
      ], heat: true);
      final geometry =
          (jsonDecode(result.heat)['features'] as List).single['geometry']
              as Map;
      expect(geometry['coordinates'], hasLength(8));
      expect(result.newHeatFragments.keys, unorderedEquals([1, 2]));
      expect(result.linesByType, isEmpty);
    });

    test('the lines mode builds no heat points', () {
      final result = buildOverviewData([ride(1, ActivityType.ski)]);
      expect(result.newHeatFragments, isEmpty);
    });
  });
}
