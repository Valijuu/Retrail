import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/db/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  Future<int> insertRide({String? title, int? date, int? start}) =>
      db.rideDao.insert(RidesCompanion.insert(
        description: Value(title),
        date: Value(date),
        startTime: Value(start),
      ));

  group('getRidesWithTrackpointsInRange', () {
    test('no filter returns all rides', () async {
      await insertRide(title: 'a', date: 100);
      await insertRide(title: 'b', date: 200);
      final res = await db.rideDao.getRidesWithTrackpointsInRange().first;
      expect(res.map((e) => e.ride.description), ['a', 'b']);
    });

    test('only startMs set excludes rides before it', () async {
      await insertRide(title: 'before', date: 50);
      await insertRide(title: 'at', date: 100);
      await insertRide(title: 'after', date: 150);
      final res =
          await db.rideDao.getRidesWithTrackpointsInRange(startMs: 100).first;
      expect(res.map((e) => e.ride.description), ['at', 'after']);
    });

    test('only endMs set excludes rides after it', () async {
      await insertRide(title: 'before', date: 50);
      await insertRide(title: 'at', date: 100);
      await insertRide(title: 'after', date: 150);
      final res =
          await db.rideDao.getRidesWithTrackpointsInRange(endMs: 100).first;
      expect(res.map((e) => e.ride.description), ['before', 'at']);
    });

    test('both set: boundaries are inclusive, one ms past endMs is excluded',
        () async {
      await insertRide(title: 'before', date: 99);
      await insertRide(title: 'atStart', date: 100);
      await insertRide(title: 'inside', date: 150);
      await insertRide(title: 'atEnd', date: 200);
      await insertRide(title: 'pastEnd', date: 201);
      final res = await db.rideDao
          .getRidesWithTrackpointsInRange(startMs: 100, endMs: 200)
          .first;
      expect(res.map((e) => e.ride.description),
          ['atStart', 'inside', 'atEnd']);
    });

    test('a ride with date == null falls back to startTime', () async {
      await insertRide(title: 'dateless', date: null, start: 150);
      await insertRide(title: 'tooEarly', date: null, start: 50);
      final res = await db.rideDao
          .getRidesWithTrackpointsInRange(startMs: 100, endMs: 200)
          .first;
      expect(res.map((e) => e.ride.description), ['dateless']);
    });

    test('date wins over a different, non-null startTime', () async {
      // date is inside [100, 200], startTime is well outside it — if the
      // query ever preferred startTime, this ride would be wrongly excluded.
      await insertRide(title: 'dateInRange', date: 150, start: 9000);
      // The inverse: startTime is inside [100, 200], date is well outside
      // it — if the query ever preferred startTime, this ride would be
      // wrongly included.
      await insertRide(title: 'startTimeInRangeOnly', date: 9000, start: 150);
      final res = await db.rideDao
          .getRidesWithTrackpointsInRange(startMs: 100, endMs: 200)
          .first;
      expect(res.map((e) => e.ride.description), ['dateInRange']);
    });
  });

  group('deleteByIds', () {
    Future<int> insertRideWithTrackpoint() async {
      final rideId = await db.rideDao
          .insert(RidesCompanion.insert(startTime: const Value(1000)));
      await db.trackpointDao.insert(TrackpointsCompanion.insert(
        rideId: rideId,
        latitude: 1,
        longitude: 1,
        timestamp: 0,
      ));
      return rideId;
    }

    test('deletes exactly the given ids, leaves others untouched', () async {
      final a = await insertRideWithTrackpoint();
      final b = await insertRideWithTrackpoint();
      final c = await insertRideWithTrackpoint();

      await db.rideDao.deleteByIds([a, c]);

      expect(await db.rideDao.getById(a).first, isNull);
      expect(await db.rideDao.getById(b).first, isNotNull);
      expect(await db.rideDao.getById(c).first, isNull);
    });

    test('cascades trackpoint deletes for every deleted ride', () async {
      final a = await insertRideWithTrackpoint();
      final b = await insertRideWithTrackpoint();
      expect(await db.trackpointDao.getAll().first, hasLength(2));

      await db.rideDao.deleteByIds([a, b]);

      expect(await db.trackpointDao.getAll().first, isEmpty);
    });
  });
}
