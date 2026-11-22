import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/distance_calculator.dart';
import 'package:retrail/domain/geo_constants.dart';

void main() {
  test('the radius is the one of the Haversine distance, in m and in km', () {
    expect(earthRadiusM, 6371000);
    expect(earthRadiusKm, 6371);
    const haversine = HaversineDistanceCalculator();
    expect(
      haversine.distanceBetween(0, 0, 1, 0),
      closeTo(metresPerDegree, 0.001),
    );
  });

  test('the degree factors convert both ways', () {
    expect(180 * radiansPerDegree, closeTo(math.pi, 1e-12));
    expect(math.pi * degreesPerRadian, closeTo(180, 1e-12));
    expect(radiansPerDegree * degreesPerRadian, closeTo(1, 1e-12));
  });

  test('one degree of latitude is about 111195 m', () {
    expect(metresPerDegree, closeTo(111195, 1));
  });
}
