import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/stats_aggregation.dart';

import 'domain_test_helpers.dart';

void main() {
  const calc = FixedDistanceCalculator(100);

  test('empty input → all zeros', () {
    final w = aggregateStats([], calc);
    expect(w.totalKm, 0);
    expect(w.rideCount, 0);
    expect(w.avgSpeedKmh, 0);
    expect(w.totalDurationSeconds, 0);
  });

  test('sums distance and duration across rides', () {
    final r1 = rwt(buildRide(startTime: 0, endTime: 3600000),
        [buildTp(), buildTp(), buildTp()]); // 200 m, 1 h
    final r2 = rwt(buildRide(startTime: 0, endTime: 3600000),
        [buildTp(), buildTp()]); // 100 m, 1 h

    final w = aggregateStats([r1, r2], calc);
    expect(w.rideCount, 2);
    expect(w.totalKm, closeTo(0.3, 1e-9)); // 300 m
    expect(w.totalDurationSeconds, 7200); // 2 h
    expect(w.avgSpeedKmh, closeTo(0.15, 1e-9)); // 0.3 km / 2 h
  });
}
