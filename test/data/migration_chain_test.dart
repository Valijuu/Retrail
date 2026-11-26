import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/db/app_database.dart';

// #139: the upgrade steps run in order on an old file. Each step must only use
// the columns that exist at its version, so these tests start from the oldest
// schemas and walk the whole chain to the current one.

const _ridesV1 = '''
  CREATE TABLE rides (
    ride_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    description TEXT, typ TEXT, start_time INTEGER,
    end_time INTEGER, date INTEGER, comment TEXT,
    is_favorite INTEGER NOT NULL DEFAULT 0 CHECK (is_favorite IN (0, 1)),
    favorited_at INTEGER)''';

const _trackpointsV1 = '''
  CREATE TABLE trackpoints (
    trackpoint_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    ride_id INTEGER NOT NULL REFERENCES rides (ride_id) ON DELETE CASCADE,
    latitude REAL NOT NULL, longitude REAL NOT NULL,
    timestamp INTEGER NOT NULL, speed REAL)''';

const _ridesV3 = '''
  CREATE TABLE rides (
    ride_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    description TEXT, typ TEXT, start_time INTEGER,
    end_time INTEGER, date INTEGER, comment TEXT,
    is_favorite INTEGER NOT NULL DEFAULT 0 CHECK (is_favorite IN (0, 1)),
    favorited_at INTEGER, distance_metres REAL,
    duration_ms INTEGER, avg_speed_kmh REAL, max_speed_kmh REAL,
    has_route INTEGER NOT NULL DEFAULT 0 CHECK (has_route IN (0, 1)))''';

AppDatabase _open(
  int version,
  List<String> schema,
  void Function(dynamic) fill,
) => AppDatabase(
  NativeDatabase.memory(
    setup: (raw) {
      for (final table in schema) {
        raw.execute(table);
      }
      fill(raw);
      raw.execute('PRAGMA user_version = $version');
    },
  ),
);

void _ride(dynamic raw) {
  raw.execute(
    "INSERT INTO rides (description, start_time, end_time, date) "
    "VALUES ('Old', 0, 60000, 0)",
  );
  raw.execute(
    'INSERT INTO trackpoints (ride_id, latitude, longitude, timestamp, speed) '
    'VALUES (1, 52.0, 13.0, 0, 2.0), (1, 52.001, 13.0, 60000, 3.0)',
  );
}

void main() {
  test('a v1 file reaches the current version with its stats filled', () async {
    final db = _open(1, [_ridesV1, _trackpointsV1], _ride);
    addTearDown(db.close);

    final ride = (await db.rideDao.getAll().first).single;
    expect(ride.description, 'Old');
    expect(ride.hasRoute, isTrue);
    expect(ride.distanceMetres, closeTo(111, 1));
    expect(ride.durationMs, 60000);
    expect(ride.maxSpeedKmh, closeTo(10.8, 1e-9));
    expect(ride.ascentM, isNull);
  });

  test('a v1 ride without points gets zero stats and no route', () async {
    final db = _open(1, [_ridesV1, _trackpointsV1], (raw) {
      raw.execute("INSERT INTO rides (description) VALUES ('Empty')");
    });
    addTearDown(db.close);

    final ride = (await db.rideDao.getAll().first).single;
    expect(ride.hasRoute, isFalse);
    expect(ride.distanceMetres, 0);
    expect(ride.durationMs, 0);
    expect(ride.avgSpeedKmh, 0);
  });

  test('a v3 file walks every step to the current version', () async {
    final db = _open(3, [_ridesV3, _trackpointsV1], _ride);
    addTearDown(db.close);

    final ride = (await db.rideDao.getAll().first).single;
    expect(ride.description, 'Old');
    expect(ride.followedRideId, isNull);
    expect(ride.followRouteMs, isNull);
    expect(ride.ascentM, isNull);
    final points = await db.trackpointDao.getByRideId(ride.rideId).first;
    expect(points, hasLength(2));
    expect(points.first.altitude, isNull);
    // v7/v8: the outline table exists with its revision column.
    final outlines = await db
        .customSelect('SELECT revision FROM ride_outlines')
        .get();
    expect(outlines, isEmpty);
  });
}
