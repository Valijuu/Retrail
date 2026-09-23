import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/ride_stats.dart';

import 'domain_test_helpers.dart';

void main() {
  const calc = FixedDistanceCalculator(100); // 100 m per segment

  test('empty trackpoints → zero distance and max speed', () {
    final s = computeRideStats(rwt(buildRide(startTime: 0, endTime: 1000), []), calc);
    expect(s.distanceMetres, 0);
    expect(s.maxSpeedKmh, 0);
    expect(s.durationMs, 1000);
  });

  test('single trackpoint → zero distance', () {
    final s = computeRideStats(
        rwt(buildRide(startTime: 0, endTime: 1000), [buildTp(speed: 5)]), calc);
    expect(s.distanceMetres, 0);
  });

  test('distance sums consecutive segments', () {
    final s = computeRideStats(
        rwt(buildRide(startTime: 0, endTime: 3600000),
            [buildTp(), buildTp(), buildTp()]),
        calc);
    expect(s.distanceMetres, 200); // 2 segments × 100 m
  });

  test('null endTime → duration 0 and avg speed 0', () {
    final s = computeRideStats(
        rwt(buildRide(startTime: 0), [buildTp(), buildTp()]), calc);
    expect(s.durationMs, 0);
    expect(s.avgSpeedKmh, 0);
  });

  test('max speed is the max provider speed × 3.6', () {
    final s = computeRideStats(
        rwt(buildRide(startTime: 0, endTime: 1000),
            [buildTp(speed: 1), buildTp(speed: 3), buildTp(speed: 2)]),
        calc);
    expect(s.maxSpeedKmh, closeTo(10.8, 1e-9));
  });

  test('avg speed = km / hours', () {
    // 3 points → 2 × 100 m = 0.2 km over 1 hour.
    final s = computeRideStats(
        rwt(buildRide(startTime: 0, endTime: 3600000),
            [buildTp(), buildTp(), buildTp()]),
        calc);
    expect(s.avgSpeedKmh, closeTo(0.2, 1e-9));
  });

  group('storedRideStats', () {
    test('returns the denormalized stats when all four columns are set', () {
      final s = storedRideStats(buildRide(
        distanceMetres: 123.4,
        durationMs: 5000,
        avgSpeedKmh: 8.8,
        maxSpeedKmh: 20.0,
      ));
      expect(s, isNotNull);
      expect(s!.distanceMetres, 123.4);
      expect(s.durationMs, 5000);
      expect(s.avgSpeedKmh, 8.8);
      expect(s.maxSpeedKmh, 20.0);
    });

    test('returns null when a ride has no stored stats yet', () {
      expect(storedRideStats(buildRide()), isNull);
    });

    test('returns null when only some columns are set (partial/corrupt row)', () {
      expect(
        storedRideStats(buildRide(distanceMetres: 1, durationMs: 2)),
        isNull,
      );
    });
  });
}
