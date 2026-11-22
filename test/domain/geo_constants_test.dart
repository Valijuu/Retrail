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

  test('one degree of latitude is about 111195 m', () {
    expect(metresPerDegree, closeTo(111195, 1));
  });
}
