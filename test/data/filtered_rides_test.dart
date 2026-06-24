import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/db/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  Future<int> insertRide(
          {String? title, String? comment, int? start, int? end, bool fav = false}) async {
    final id = await db.rideDao.insert(RidesCompanion.insert(
      description: Value(title),
      comment: Value(comment),
      startTime: Value(start),
      endTime: Value(end),
    ));
    if (fav) await db.rideDao.updateFavorite(id, true, start ?? 0);
    return id;
  }

  test('search matches description OR comment', () async {
    await insertRide(title: 'Beach run', start: 1);
    await insertRide(title: 'Park', comment: 'sunny beach day', start: 2);
    await insertRide(title: 'City', start: 3);

    final res = await db.rideDao.getFilteredRides(searchQuery: 'beach').first;
    expect(res.map((r) => r.description), containsAll(['Beach run', 'Park']));
    expect(res.map((r) => r.description), isNot(contains('City')));
  });

  test('startTime = 0 returns all rides', () async {
    await insertRide(title: 'a', start: 1);
    await insertRide(title: 'b', start: 2);
    final res = await db.rideDao.getFilteredRides().first;
    expect(res, hasLength(2));
  });

  test('startTime cutoff filters older rides', () async {
    await insertRide(title: 'old', start: 100);
    await insertRide(title: 'new', start: 500);
    final res = await db.rideDao.getFilteredRides(startTime: 200).first;
    expect(res.map((r) => r.description), ['new']);
  });

  test("sortBy 'duration' orders by duration asc", () async {
    await insertRide(title: 'long', start: 0, end: 1000); // 1000
    await insertRide(title: 'short', start: 0, end: 100); // 100
    await insertRide(title: 'mid', start: 0, end: 500); // 500
    final res = await db.rideDao.getFilteredRides(sortBy: 'duration').first;
    expect(res.map((r) => r.description), ['short', 'mid', 'long']);
  });

  test("default sort is startTime desc", () async {
    await insertRide(title: 'first', start: 100);
    await insertRide(title: 'third', start: 300);
    await insertRide(title: 'second', start: 200);
    final res = await db.rideDao.getFilteredRides().first;
    expect(res.map((r) => r.description), ['third', 'second', 'first']);
  });

  test('getFilteredFavoriteRides returns only favorites', () async {
    await insertRide(title: 'fav', start: 1, fav: true);
    await insertRide(title: 'plain', start: 2);
    final res = await db.rideDao.getFilteredFavoriteRides().first;
    expect(res.map((r) => r.description), ['fav']);
  });
}
