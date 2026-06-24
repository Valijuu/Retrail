import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/db/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  Future<int> insertRide() =>
      db.rideDao.insert(RidesCompanion.insert(startTime: const Value(1000)));

  TrackpointsCompanion tp(int rideId, double lat, double lng,
          {int ts = 0, double? speed}) =>
      TrackpointsCompanion.insert(
        rideId: rideId,
        latitude: lat,
        longitude: lng,
        timestamp: ts,
        speed: Value(speed),
      );

  test('insert + getById round-trips', () async {
    final rideId = await insertRide();
    final id = await db.trackpointDao.insert(tp(rideId, 1.0, 2.0, ts: 5, speed: 3.5));
    final fetched = await db.trackpointDao.getById(id).first;
    expect(fetched!.latitude, 1.0);
    expect(fetched.longitude, 2.0);
    expect(fetched.timestamp, 5);
    expect(fetched.speed, 3.5);
  });

  test('insertAll inserts every point and getAllByIds reads them', () async {
    final rideId = await insertRide();
    final ids = await db.trackpointDao.insertAll([
      tp(rideId, 1, 1),
      tp(rideId, 2, 2),
      tp(rideId, 3, 3),
    ]);
    expect(ids, hasLength(3));
    final fetched = await db.trackpointDao.getAllByIds(ids).first;
    expect(fetched, hasLength(3));
  });

  test('deleting a ride CASCADE-deletes its trackpoints', () async {
    final rideId = await insertRide();
    await db.trackpointDao.insertAll([tp(rideId, 1, 1), tp(rideId, 2, 2)]);
    expect(await db.trackpointDao.getAll().first, hasLength(2));

    await db.rideDao.deleteById(rideId);

    expect(await db.trackpointDao.getAll().first, isEmpty);
  });

  test('deleteById removes a single trackpoint', () async {
    final rideId = await insertRide();
    final id = await db.trackpointDao.insert(tp(rideId, 1, 1));
    await db.trackpointDao.deleteById(id);
    expect(await db.trackpointDao.getById(id).first, isNull);
  });
}
