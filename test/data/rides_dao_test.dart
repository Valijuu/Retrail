import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/db/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  RidesCompanion ride({String? title, int? start, int? end}) => RidesCompanion.insert(
        description: Value(title),
        startTime: Value(start),
        endTime: Value(end),
      );

  test('insert returns an id and getById reads it back', () async {
    final id = await db.rideDao.insert(ride(title: 'Morning cruise', start: 1000));
    final fetched = await db.rideDao.getById(id).first;
    expect(fetched, isNotNull);
    expect(fetched!.rideId, id);
    expect(fetched.description, 'Morning cruise');
    expect(fetched.isFavorite, false);
  });

  test('getAll returns every inserted ride', () async {
    await db.rideDao.insert(ride(title: 'A'));
    await db.rideDao.insert(ride(title: 'B'));
    final all = await db.rideDao.getAll().first;
    expect(all.map((r) => r.description), containsAll(['A', 'B']));
  });

  test('upsert updates an existing row in place', () async {
    final id = await db.rideDao.insert(ride(title: 'first'));
    await db.rideDao
        .insert(RidesCompanion(rideId: Value(id), description: const Value('renamed')));
    final all = await db.rideDao.getAll().first;
    expect(all, hasLength(1));
    expect(all.single.description, 'renamed');
  });

  test('updateEndTime / updateRideDetails / updateRideType mutate columns', () async {
    final id = await db.rideDao.insert(ride(title: 'x', start: 100));
    await db.rideDao.updateEndTime(id, 999);
    await db.rideDao.updateRideDetails(id, 'title2', 'note2');
    await db.rideDao.updateRideType(id, 'SKATEBOARD');
    final r = await db.rideDao.getById(id).first;
    expect(r!.endTime, 999);
    expect(r.description, 'title2');
    expect(r.comment, 'note2');
    expect(r.typ, 'SKATEBOARD');
  });

  test('updateFavorite writes both is_favorite and favorited_at', () async {
    final id = await db.rideDao.insert(ride(title: 'fav'));
    await db.rideDao.updateFavorite(id, true, 5550);
    var r = await db.rideDao.getById(id).first;
    expect(r!.isFavorite, true);
    expect(r.favoritedAt, 5550);

    await db.rideDao.updateFavorite(id, false, null);
    r = await db.rideDao.getById(id).first;
    expect(r!.isFavorite, false);
    expect(r.favoritedAt, isNull);
  });

  test('getFavoriteRides returns only favorites, newest startTime first', () async {
    final a = await db.rideDao.insert(ride(title: 'a', start: 100));
    final b = await db.rideDao.insert(ride(title: 'b', start: 300));
    await db.rideDao.insert(ride(title: 'c', start: 200)); // not favorite
    await db.rideDao.updateFavorite(a, true, 1);
    await db.rideDao.updateFavorite(b, true, 2);
    final favs = await db.rideDao.getFavoriteRides().first;
    expect(favs.map((r) => r.description), ['b', 'a']);
  });

  test('deleteById removes the ride', () async {
    final id = await db.rideDao.insert(ride(title: 'gone'));
    await db.rideDao.deleteById(id);
    expect(await db.rideDao.getById(id).first, isNull);
  });

  test('getRidesWithTrackpointsBetween filters by startTime (inclusive)', () async {
    await db.rideDao.insert(ride(title: 'before', start: 50));
    await db.rideDao.insert(ride(title: 'inside', start: 150));
    await db.rideDao.insert(ride(title: 'after', start: 350));
    final res = await db.rideDao.getRidesWithTrackpointsBetween(100, 300).first;
    expect(res.map((e) => e.ride.description), ['inside']);
  });
}
