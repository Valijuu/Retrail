import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/repositories/ride_repository.dart';

import '../domain/domain_test_helpers.dart' show FixedDistanceCalculator;

void main() {
  late AppDatabase db;
  late RideRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    repo = RideRepository(db.rideDao,
        now: () => 424242, calc: const FixedDistanceCalculator(100));
  });
  tearDown(() => db.close());

  test('updateFavorite(true) stamps favoritedAt with the injected clock', () async {
    final id = await repo.startRide(startedAtMs: 1);
    await repo.updateFavorite(id, true);
    final r = await repo.getById(id).first;
    expect(r!.isFavorite, true);
    expect(r.favoritedAt, 424242);
  });

  test('updateFavorite(false) clears favoritedAt', () async {
    final id = await repo.startRide(startedAtMs: 1);
    await repo.updateFavorite(id, true);
    await repo.updateFavorite(id, false);
    final r = await repo.getById(id).first;
    expect(r!.isFavorite, false);
    expect(r.favoritedAt, isNull);
  });

  test('repository delegates reads to the dao', () async {
    final id = await repo.startRide(startedAtMs: 1);
    await repo.updateRideDetails(id, 'via repo', null);
    final all = await repo.getAllRides().first;
    expect(all.single.description, 'via repo');
  });

  test('updateEndTime stamps endTime and caches computed stats on the row',
      () async {
    final id = await repo.startRide(startedAtMs: 0);
    await db.trackpointDao.insertAll([
      TrackpointsCompanion.insert(rideId: id, latitude: 0, longitude: 0, timestamp: 0),
      TrackpointsCompanion.insert(rideId: id, latitude: 0, longitude: 0, timestamp: 1000),
      TrackpointsCompanion.insert(rideId: id, latitude: 0, longitude: 0, timestamp: 2000),
    ]);

    await repo.updateEndTime(id, 3600000); // 1 hour

    final r = await repo.getById(id).first;
    expect(r!.endTime, 3600000);
    expect(r.distanceMetres, 200); // 2 segments × 100 m (FixedDistanceCalculator)
    expect(r.durationMs, 3600000);
    expect(r.avgSpeedKmh, closeTo(0.2, 1e-9)); // 0.2 km / 1 h
    expect(r.hasRoute, isTrue);
  });

  test('updateEndTime on a ride with no trackpoints stores zeroed stats and '
      'hasRoute=false', () async {
    final id = await repo.startRide(startedAtMs: 0);
    await repo.updateEndTime(id, 1000);
    final r = await repo.getById(id).first;
    expect(r!.distanceMetres, 0);
    expect(r.maxSpeedKmh, 0);
    expect(r.hasRoute, isFalse);
  });
}
