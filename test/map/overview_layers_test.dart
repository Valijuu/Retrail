import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/activity_type.dart';
import 'package:retrail/domain/distance_calculator.dart';
import 'package:retrail/map/overview_layers.dart';

void main() {
  test('each activity type has its own source id', () {
    final ids = {for (final t in ActivityType.values) overviewSourceId(t)};
    expect(ids, hasLength(ActivityType.values.length));
  });

  test('no point is the empty collection', () {
    expect(overviewPointGeoJson(null), emptyOverviewGeoJson);
  });

  test('a point is written as longitude, latitude', () {
    final json = jsonDecode(overviewPointGeoJson((lat: 48.1, lng: 11.5)));
    expect(json['geometry']['coordinates'], [11.5, 48.1]);
  });

  test('the area circle is a closed ring at the radius from the pin', () {
    const pin = (lat: 48.1, lng: 11.5);
    final json = jsonDecode(areaCircleGeoJson(pin, 10));
    final ring = (json['geometry']['coordinates'][0] as List)
        .map(
          (p) => (lat: (p[1] as num).toDouble(), lng: (p[0] as num).toDouble()),
        )
        .toList();
    expect(ring.first, ring.last);
    for (final p in ring) {
      final d = const HaversineDistanceCalculator().distanceBetween(
        pin.lat,
        pin.lng,
        p.lat,
        p.lng,
      );
      expect(d, closeTo(10000, 10));
    }
  });
}
