import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/db/app_database.dart';

void main() {
  test('schema version is 7', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    expect(db.schemaVersion, 7);
  });

  test('a trackpoint round-trips its altitude, or none', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final id = await db.rideDao.insert(
      RidesCompanion.insert(startTime: const Value(1)),
    );
    await db.trackpointDao.insert(
      TrackpointsCompanion.insert(
        rideId: id,
        latitude: 0,
        longitude: 0,
        timestamp: 1,
        altitude: const Value(123.5),
      ),
    );
    await db.trackpointDao.insert(
      TrackpointsCompanion.insert(
        rideId: id,
        latitude: 0,
        longitude: 0,
        timestamp: 2,
      ),
    );
    final points = await db.trackpointDao.getByRideId(id).first;
    expect(points.map((p) => p.altitude), [123.5, null]);
  });

  test(
    'upgrading from v5 keeps rides and adds empty elevation columns',
    () async {
      final db = AppDatabase(
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
              follow_route_ms INTEGER
            )''');
            raw.execute('''
            CREATE TABLE trackpoints (
              trackpoint_id INTEGER PRIMARY KEY AUTOINCREMENT,
              ride_id INTEGER NOT NULL REFERENCES rides (ride_id) ON DELETE CASCADE,
              latitude REAL NOT NULL, longitude REAL NOT NULL,
              timestamp INTEGER NOT NULL, speed REAL
            )''');
            raw.execute(
              "INSERT INTO rides (description, start_time) VALUES ('old', 5)",
            );
            raw.execute(
              'INSERT INTO trackpoints (ride_id, latitude, longitude, timestamp) VALUES (1, 1, 2, 3)',
            );
            raw.execute('PRAGMA user_version = 5');
          },
        ),
      );
      addTearDown(db.close);

      final rides = await db.rideDao.getAll().first;
      expect(rides.single.description, 'old');
      expect(rides.single.ascentM, isNull);
      expect(rides.single.descentM, isNull);
      final points = await db.trackpointDao.getByRideId(1).first;
      expect(points.single.altitude, isNull);
    },
  );
}
