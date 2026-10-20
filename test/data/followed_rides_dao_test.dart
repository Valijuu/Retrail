import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/db/followed_route.dart';

/// Spec 20: a ride recorded while following another one links to it.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  Future<int> ride({String? title, int? date}) => db.rideDao.insert(
    RidesCompanion.insert(description: Value(title), date: Value(date)),
  );

  Future<int> follow(int originalId, {double coverage = 1, int? date}) async {
    final id = await ride(date: date);
    await db.rideDao.updateFollowedRide(id, originalId, coverage);
    return id;
  }

  test('updateFollowedRide stores the original and the coverage', () async {
    final original = await ride(title: 'Hausrunde');
    final id = await follow(original, coverage: 0.95);

    final stored = await db.rideDao.findById(id);
    expect(stored!.followedRideId, original);
    expect(stored.followCoverage, 0.95);
  });

  test('routeRootId is the original for a follow, the ride itself '
      'otherwise', () async {
    final original = await ride();
    final id = await follow(original);
    expect((await db.rideDao.findById(original))!.routeRootId, original);
    expect((await db.rideDao.findById(id))!.routeRootId, original);
  });

  test('a ride without a follow has no link', () async {
    final id = await ride();
    final stored = await db.rideDao.findById(id);
    expect(stored!.followedRideId, isNull);
    expect(stored.followCoverage, isNull);
  });

  test(
    'deleting the original keeps its follows, unlinked (deleteById)',
    () async {
      final original = await ride();
      final id = await follow(original);

      await db.rideDao.deleteById(original);

      final stored = await db.rideDao.findById(id);
      expect(stored, isNotNull);
      expect(stored!.followedRideId, isNull);
    },
  );

  test(
    'deleting the original keeps its follows, unlinked (deleteByIds)',
    () async {
      final original = await ride();
      final other = await ride();
      final id = await follow(original);

      await db.rideDao.deleteByIds([original, other]);

      final stored = await db.rideDao.findById(id);
      expect(stored, isNotNull);
      expect(stored!.followedRideId, isNull);
    },
  );

  test('watchFollowCounts counts the follows per original', () async {
    final a = await ride();
    final b = await ride();
    await ride();
    await follow(a);
    await follow(a);
    await follow(b);

    expect(await db.rideDao.watchFollowCounts().first, {a: 2, b: 1});
  });

  test('watchRouteGroup lists the original and its follows only', () async {
    final a = await ride();
    final b = await ride();
    final f1 = await follow(a);
    final f2 = await follow(a);
    await follow(b);

    final group = await db.rideDao.watchRouteGroup(a).first;
    expect(group.map((r) => r.rideId), unorderedEquals([a, f1, f2]));
  });

  test('watchRouteGroup is empty once the original is gone', () async {
    final a = await ride();
    await follow(a);
    await db.rideDao.deleteById(a);

    expect(await db.rideDao.watchRouteGroup(a).first, isEmpty);
  });

  test(
    'watchFollowedRoutes lists followed originals, most recently ridden first',
    () async {
      final a = await ride(title: 'Hausrunde', date: 100);
      final b = await ride(title: 'Rheinufer', date: 200);
      await ride(title: 'Never followed', date: 900);
      await follow(a, date: 500);
      await follow(a, date: 300);
      await follow(b, date: 400);

      final routes = await db.rideDao.watchFollowedRoutes().first;
      expect(routes.map((r) => r.original.rideId), [a, b]);
      expect(routes.map((r) => r.rideCount), [3, 2]);
      expect(routes.map((r) => r.lastRiddenMs), [500, 400]);
    },
  );

  test('migrating v3 to v4 keeps every ride, unlinked', () async {
    final v3 = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('''
            CREATE TABLE rides (
              ride_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              description TEXT, typ TEXT, start_time INTEGER,
              end_time INTEGER, date INTEGER, comment TEXT,
              is_favorite INTEGER NOT NULL DEFAULT 0
                CHECK (is_favorite IN (0, 1)),
              favorited_at INTEGER, distance_metres REAL,
              duration_ms INTEGER, avg_speed_kmh REAL, max_speed_kmh REAL,
              has_route INTEGER NOT NULL DEFAULT 0
                CHECK (has_route IN (0, 1)))''');
          raw.execute('''
            CREATE TABLE trackpoints (
              trackpoint_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              ride_id INTEGER NOT NULL
                REFERENCES rides (ride_id) ON DELETE CASCADE,
              latitude REAL NOT NULL, longitude REAL NOT NULL,
              timestamp INTEGER NOT NULL, speed REAL)''');
          raw.execute(
            "INSERT INTO rides (description, has_route) VALUES ('Old', 0)",
          );
          raw.execute('PRAGMA user_version = 3');
        },
      ),
    );
    addTearDown(v3.close);

    final rides = await v3.rideDao.getAll().first;
    expect(rides.single.description, 'Old');
    expect(rides.single.followedRideId, isNull);
    expect(rides.single.followCoverage, isNull);

    final id = await v3.rideDao.insert(
      RidesCompanion.insert(description: const Value('New')),
    );
    await v3.rideDao.updateFollowedRide(id, rides.single.rideId, 0.5);
    await v3.rideDao.deleteById(rides.single.rideId);
    expect((await v3.rideDao.findById(id))!.followedRideId, isNull);
  });
}
