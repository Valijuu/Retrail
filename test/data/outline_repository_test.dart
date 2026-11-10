import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/repositories/outline_repository.dart';
import 'package:retrail/data/repositories/ride_repository.dart';
import 'package:retrail/domain/ride_outline.dart';

/// Ten fixes in a straight line eastwards, 1 m apart.
Future<void> _addLine(AppDatabase db, int rideId) async {
  for (var i = 0; i < 10; i++) {
    await db.trackpointDao.insert(
      TrackpointsCompanion.insert(
        rideId: rideId,
        latitude: 48,
        longitude: 11 + i * 0.00001,
        timestamp: i,
      ),
    );
  }
}

void main() {
  late AppDatabase db;
  late OutlineRepository outlines;
  late RideRepository rides;

  setUp(() {
    db = AppDatabase.memory();
    outlines = OutlineRepository(db.outlineDao, db.trackpointDao);
    rides = RideRepository(db.rideDao, outlines: outlines);
  });
  tearDown(() => db.close());

  test('saving a ride stores its simplified outline', () async {
    final id = await rides.startRide(startedAtMs: 0);
    await _addLine(db, id);
    await rides.updateEndTime(id, 10);

    final row = await db.outlineDao.findByRideId(id);
    final outline = RideOutline.decode(row!.polyline);
    expect(outline.points.length, 2);
    expect(row.south, closeTo(48, 1e-9));
    expect(row.east, closeTo(11.00009, 1e-9));
  });

  test('a ride without trackpoints gets no outline row', () async {
    final id = await rides.startRide(startedAtMs: 0);
    await rides.updateEndTime(id, 10);
    expect(await db.outlineDao.getAll(), isEmpty);
  });

  test('fillNext fills one ride at a time and reports what is left', () async {
    for (var i = 0; i < 2; i++) {
      final id = await rides.startRide(startedAtMs: i);
      await _addLine(db, id);
      await db.rideDao.updateStats(
        id,
        distanceMetres: 1,
        durationMs: 1,
        avgSpeedKmh: 1,
        maxSpeedKmh: 1,
        hasRoute: true,
      );
    }
    expect(await outlines.fillNext(), isTrue);
    expect(await db.outlineDao.getAll(), hasLength(1));
    expect(await outlines.fillNext(), isFalse); // the last one
    expect(await db.outlineDao.getAll(), hasLength(2));
    expect(await outlines.fillNext(), isFalse); // nothing left to do
  });

  test('a ride deleted while its outline is computed gets no row', () async {
    final id = await rides.startRide(startedAtMs: 0);
    await _addLine(db, id);
    await db.rideDao.updateStats(
      id,
      distanceMetres: 1,
      durationMs: 1,
      avgSpeedKmh: 1,
      maxSpeedKmh: 1,
      hasRoute: true,
    );
    final fill = outlines.fillNext(afterRead: () => rides.deleteById(id));
    await fill;
    expect(await db.outlineDao.getAll(), isEmpty);
  });

  test('saving the outline of a gone ride is ignored', () async {
    await outlines.save(999, const [
      (lat: 1.0, lng: 2.0),
      (lat: 1.1, lng: 2.1),
    ]);
    expect(await db.outlineDao.getAll(), isEmpty);
  });
}
