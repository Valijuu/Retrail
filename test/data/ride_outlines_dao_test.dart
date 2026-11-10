import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/db/app_database.dart';

Future<int> _ride(AppDatabase db) => db.rideDao.insert(
  RidesCompanion.insert(startTime: const Value(1), hasRoute: const Value(true)),
);

RideOutlinesCompanion _outline(int rideId, {String polyline = 'abc'}) =>
    RideOutlinesCompanion.insert(
      rideId: Value(rideId),
      polyline: polyline,
      south: 1,
      west: 2,
      north: 3,
      east: 4,
    );

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  test('schema version is 7', () {
    expect(db.schemaVersion, 7);
  });

  test('an outline round-trips by ride id', () async {
    final id = await _ride(db);
    await db.outlineDao.upsert(_outline(id));
    final outline = await (db.select(
      db.rideOutlines,
    )..where((o) => o.rideId.equals(id))).getSingleOrNull();
    expect(outline?.polyline, 'abc');
    expect(
      (outline!.south, outline.west, outline.north, outline.east),
      (1.0, 2.0, 3.0, 4.0),
    );
  });

  test('upsert replaces the outline of a ride', () async {
    final id = await _ride(db);
    await db.outlineDao.upsert(_outline(id));
    await db.outlineDao.upsert(_outline(id, polyline: 'xyz'));
    expect((await db.select(db.rideOutlines).get()).single.polyline, 'xyz');
  });

  test('an outline for a ride that does not exist is ignored', () async {
    await db.outlineDao.upsert(_outline(999));
    expect(await db.select(db.rideOutlines).get(), isEmpty);
  });

  test('deleting a ride deletes its outline', () async {
    final id = await _ride(db);
    await db.outlineDao.upsert(_outline(id));
    await db.rideDao.deleteById(id);
    expect(await db.select(db.rideOutlines).get(), isEmpty);
  });

  test('batch delete removes the outlines of all rides in one go', () async {
    final a = await _ride(db);
    final b = await _ride(db);
    final c = await _ride(db);
    for (final id in [a, b, c]) {
      await db.outlineDao.upsert(_outline(id));
    }
    await db.rideDao.deleteByIds([a, b]);
    expect((await db.select(db.rideOutlines).get()).map((o) => o.rideId), [c]);
  });

  test('rides without an outline are listed for the background fill', () async {
    final a = await _ride(db);
    final b = await _ride(db);
    await db.outlineDao.upsert(_outline(a));
    expect(await db.outlineDao.rideIdsWithoutOutline(), [b]);
  });

  test('upgrading from v6 keeps rides and adds an empty outline table', () async {
    final upgraded = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('''
            CREATE TABLE rides (
              ride_id INTEGER PRIMARY KEY AUTOINCREMENT,
              description TEXT, typ TEXT, start_time INTEGER, end_time INTEGER,
              date INTEGER, comment TEXT,
              is_favorite INTEGER NOT NULL DEFAULT 0, favorited_at INTEGER,
              distance_metres REAL, duration_ms INTEGER, avg_speed_kmh REAL,
              max_speed_kmh REAL, has_route INTEGER NOT NULL DEFAULT 0,
              followed_ride_id INTEGER, follow_coverage REAL,
              follow_route_ms INTEGER, ascent_m REAL, descent_m REAL
            )''');
          raw.execute('''
            CREATE TABLE trackpoints (
              trackpoint_id INTEGER PRIMARY KEY AUTOINCREMENT,
              ride_id INTEGER NOT NULL REFERENCES rides (ride_id) ON DELETE CASCADE,
              latitude REAL NOT NULL, longitude REAL NOT NULL,
              timestamp INTEGER NOT NULL, speed REAL, altitude REAL
            )''');
          raw.execute(
            "INSERT INTO rides (description, start_time, has_route) VALUES ('old', 5, 1)",
          );
          raw.execute('PRAGMA user_version = 6');
        },
      ),
    );
    addTearDown(upgraded.close);
    expect((await upgraded.rideDao.getAll().first).single.description, 'old');
    expect(await upgraded.select(upgraded.rideOutlines).get(), isEmpty);
    expect(await upgraded.outlineDao.rideIdsWithoutOutline(), [1]);
  });

  test('a ride without a route is not listed for the fill', () async {
    await db.rideDao.insert(RidesCompanion.insert(startTime: const Value(1)));
    expect(await db.outlineDao.rideIdsWithoutOutline(), isEmpty);
  });

  test('getByRideIds loads only the outlines asked for', () async {
    final a = await _ride(db);
    final b = await _ride(db);
    final c = await _ride(db);
    for (final id in [a, b, c]) {
      await db.outlineDao.upsert(_outline(id));
    }
    final rows = await db.outlineDao.getByRideIds([a, c, 999]);
    expect(rows.map((o) => o.rideId), unorderedEquals([a, c]));
    expect(await db.outlineDao.getByRideIds(const []), isEmpty);
  });

  test('watchOutlinedRideIds follows added and removed outlines', () async {
    final a = await _ride(db);
    final emissions = <Set<int>>[];
    final sub = db.outlineDao.watchOutlinedRideIds().listen(emissions.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();
    await db.outlineDao.upsert(_outline(a));
    await pumpEventQueue();
    await db.rideDao.deleteById(a);
    await pumpEventQueue();
    expect(emissions, [
      <int>{},
      {a},
      <int>{},
    ]);
  });
}
