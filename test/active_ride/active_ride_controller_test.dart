import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Brightness;

import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/db/ride_dao.dart';
import 'package:retrail/data/db/trackpoint_dao.dart';
import 'package:retrail/data/repositories/ride_repository.dart';
import 'package:retrail/data/repositories/trackpoint_repository.dart';
import 'package:retrail/domain/distance_calculator.dart';
import 'package:retrail/features/active_ride/active_ride_controller.dart';
import 'package:retrail/map/preview_projection.dart';
import 'package:retrail/map/route_preview_cache.dart';
import 'package:retrail/tracking/location_fix.dart';
import 'package:retrail/tracking/ride_tracker.dart';

LocationFix _fix(double lat, double lng, int ageNanos) => LocationFix(
      latitude: lat,
      longitude: lng,
      accuracy: 5,
      hasSpeed: true,
      speed: 5, // m/s, above the stationary guard
      elapsedRealtimeNanos: ageNanos,
    );

void main() {
  late AppDatabase db;
  late RideTracker tracker;

  setUp(() {
    db = AppDatabase.memory();
    tracker = RideTracker(
      RideRepository(RideDao(db)),
      TrackpointRepository(TrackpointDao(db)),
      const HaversineDistanceCalculator(),
      nowMs: () => 1000,
      nowNanos: () => 10000000000, // 10 s — keeps the fixes below "fresh"
    );
  });

  tearDown(() async {
    tracker.dispose();
    await db.close();
  });

  /// Records a 2-point ride, then stops it.
  Future<void> recordShortRide() async {
    tracker.startTracking();
    await pumpEventQueue(); // let _beginRide insert + set the active ride id
    tracker.onLocationReceived(_fix(52.0, 13.0, 8000000000));
    // ~12 m north over 1 s → passes the displacement + speed filters.
    tracker.onLocationReceived(_fix(52.000108, 13.0, 9000000000));
    tracker.stopTracking();
    await pumpEventQueue();
  }

  test('saveRide persists details and generates the preview once', () async {
    await recordShortRide();
    expect(tracker.state.trackPoints.length, 2);

    final tmp = await Directory.systemTemp.createTemp('preview_test');
    addTearDown(() => tmp.delete(recursive: true));

    List<RoutePoint>? captured;
    final cache = RoutePreviewCache(
      baseDir: tmp,
      render: (points, _) async {
        captured = points;
        return Uint8List.fromList([1, 2, 3]);
      },
    );
    final controller = ActiveRideController(tracker, cache);
    final rideId = tracker.lastCompletedRideId!;

    await controller.saveRide(title: 'Sunset', comment: 'nice', favorite: true);

    // Preview generated with the recorded route.
    expect(captured, isNotNull);
    expect(captured!.length, 2);
    expect(
        await cache.fileFor(rideId, brightness: Brightness.light).exists(),
        isTrue);

    // Details persisted to the DB.
    await pumpEventQueue();
    final ride = await RideRepository(RideDao(db)).getById(rideId).first;
    expect(ride!.description, 'Sunset');
    expect(ride.comment, 'nice');
    expect(ride.isFavorite, isTrue);
  });

  test('saveRide in dark mode pre-generates the dark preview variant',
      () async {
    await recordShortRide();
    final tmp = await Directory.systemTemp.createTemp('preview_test');
    addTearDown(() => tmp.delete(recursive: true));

    Brightness? renderedWith;
    final cache = RoutePreviewCache(
      baseDir: tmp,
      render: (points, b) async {
        renderedWith = b;
        return Uint8List.fromList([1]);
      },
    );
    final controller = ActiveRideController(tracker, cache,
        currentBrightness: () => Brightness.dark);
    final rideId = tracker.lastCompletedRideId!;

    await controller.saveRide();

    expect(renderedWith, Brightness.dark); // rendered for the active theme
    expect(await cache.fileFor(rideId, brightness: Brightness.dark).exists(),
        isTrue);
  });

  test('saveRide skips preview generation when the ride has no route', () async {
    tracker.startTracking();
    await pumpEventQueue();
    tracker.stopTracking(); // no fixes → empty route
    await pumpEventQueue();

    final tmp = await Directory.systemTemp.createTemp('preview_test');
    addTearDown(() => tmp.delete(recursive: true));

    var rendered = false;
    final cache = RoutePreviewCache(
      baseDir: tmp,
      render: (points, _) async {
        rendered = true;
        return Uint8List(0);
      },
    );
    final controller = ActiveRideController(tracker, cache);

    await controller.saveRide(title: 'Empty');
    expect(rendered, isFalse);
  });

  test('startRide does not start a second ride when already tracking',
      () async {
    final tmp = await Directory.systemTemp.createTemp('preview_test');
    addTearDown(() => tmp.delete(recursive: true));
    final controller = ActiveRideController(
      tracker,
      RoutePreviewCache(baseDir: tmp, render: (_, _) async => Uint8List(0)),
    );

    controller.startRide();
    await pumpEventQueue(); // first ride inserted
    controller.startRide(); // already tracking → guarded no-op
    await pumpEventQueue();

    final rides = await db.rideDao.getAll().first;
    expect(rides.length, 1);
  });

  test('discardRide deletes the stopped ride', () async {
    await recordShortRide();
    final rideId = tracker.lastCompletedRideId!;
    final repo = RideRepository(RideDao(db));
    expect(await repo.getById(rideId).first, isNotNull);

    final tmp = await Directory.systemTemp.createTemp('preview_test');
    addTearDown(() => tmp.delete(recursive: true));
    final controller = ActiveRideController(
      tracker,
      RoutePreviewCache(baseDir: tmp, render: (_, _) async => Uint8List(0)),
    );

    controller.discardRide();
    await pumpEventQueue();
    expect(await repo.getById(rideId).first, isNull);
  });
}
