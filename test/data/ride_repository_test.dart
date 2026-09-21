import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/repositories/ride_repository.dart';

void main() {
  late AppDatabase db;
  late RideRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    repo = RideRepository(db.rideDao, now: () => 424242);
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
}
