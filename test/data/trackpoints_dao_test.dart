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

  test('insert + getByRideId round-trips', () async {
    final rideId = await insertRide();
    await db.trackpointDao.insert(tp(rideId, 1.0, 2.0, ts: 5, speed: 3.5));
    final fetched = (await db.trackpointDao.getByRideId(rideId).first).single;
    expect(fetched.latitude, 1.0);
    expect(fetched.longitude, 2.0);
    expect(fetched.timestamp, 5);
    expect(fetched.speed, 3.5);
  });

  test('getByRideId returns only that ride\'s points', () async {
    final a = await insertRide();
    final b = await insertRide();
    await db.trackpointDao.insert(tp(a, 1, 1));
    await db.trackpointDao.insert(tp(a, 2, 2));
    await db.trackpointDao.insert(tp(b, 3, 3));
    expect(await db.trackpointDao.getByRideId(a).first, hasLength(2));
    expect(await db.trackpointDao.getByRideId(b).first, hasLength(1));
  });

  test('deleting a ride CASCADE-deletes its trackpoints', () async {
    final rideId = await insertRide();
    await db.trackpointDao.insert(tp(rideId, 1, 1));
    await db.trackpointDao.insert(tp(rideId, 2, 2));
    expect(await db.trackpointDao.getByRideId(rideId).first, hasLength(2));

    await db.rideDao.deleteById(rideId);

    expect(await db.trackpointDao.getByRideId(rideId).first, isEmpty);
  });
}
