import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/repositories/ride_repository.dart';
import 'package:retrail/domain/distance_calculator.dart';
import 'package:retrail/domain/stats_aggregation.dart';
import 'package:retrail/domain/time_bounds.dart';

import 'home_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('week/day/year stats aggregate the right rides', () async {
    final env = await buildHomeEnv();
    addTearDown(env.db.close);
    final now = DateTime(2026, 6, 17, 12); // a Wednesday
    final lastMonth = DateTime(2026, 5, 1, 12);

    await insertRide(env.db,
        startTime: now.millisecondsSinceEpoch,
        endTime: now.add(const Duration(hours: 1)).millisecondsSinceEpoch);
    await insertRide(env.db,
        startTime: lastMonth.millisecondsSinceEpoch,
        endTime: lastMonth.add(const Duration(hours: 1)).millisecondsSinceEpoch);

    final repo = RideRepository(env.db.rideDao);
    const calc = HaversineDistanceCalculator();
    Future<WeeklyStats> statsFor(Bounds b) async =>
        aggregateStats(await repo.getRidesWithTrackpointsBetween(b.$1, b.$2).first, calc);

    final weekly = await statsFor(weekBounds(nowMs: now.millisecondsSinceEpoch));
    final daily = await statsFor(dayBounds(nowMs: now.millisecondsSinceEpoch));
    final yearly = await statsFor(yearBounds(nowMs: now.millisecondsSinceEpoch));

    expect(weekly.rideCount, 1);
    expect(weekly.totalDurationSeconds, 3600);
    expect(daily.rideCount, 1);
    expect(yearly.rideCount, 2);
  });
}
