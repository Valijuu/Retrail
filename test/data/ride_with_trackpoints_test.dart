import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/db/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  Future<int> insertRide(String title) =>
      db.rideDao.insert(RidesCompanion.insert(description: Value(title)));

  Future<void> addPoint(int rideId, double lat) => db.trackpointDao.insert(
        TrackpointsCompanion.insert(
            rideId: rideId, latitude: lat, longitude: 0, timestamp: 0),
      );

  test('assembly zips each ride to its own trackpoints', () async {
    final a = await insertRide('A');
    final b = await insertRide('B');
    await addPoint(a, 1);
    await addPoint(a, 2);
    await addPoint(b, 9);

    final all = await db.rideDao.getAllRidesWithTrackpoints().first;
    final byTitle = {for (final e in all) e.ride.description: e};

    expect(byTitle['A']!.trackpoints.map((t) => t.latitude), [1, 2]);
    expect(byTitle['B']!.trackpoints.map((t) => t.latitude), [9]);
  });

  test('a ride with no trackpoints yields an empty list', () async {
    final id = await insertRide('lonely');
    final res = await db.rideDao.getRideWithTrackpointsById(id).first;
    expect(res, isNotNull);
    expect(res!.trackpoints, isEmpty);
  });

  test('getRideWithTrackpointsById returns null for a missing ride', () async {
    expect(await db.rideDao.getRideWithTrackpointsById(999).first, isNull);
  });
}
