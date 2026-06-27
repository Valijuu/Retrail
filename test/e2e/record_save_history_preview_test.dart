import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/db/ride_dao.dart';
import 'package:retrail/data/db/trackpoint_dao.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/data/repositories/ride_repository.dart';
import 'package:retrail/data/repositories/trackpoint_repository.dart';
import 'package:retrail/domain/distance_calculator.dart';
import 'package:retrail/features/active_ride/active_ride_controller.dart';
import 'package:retrail/features/history/history_items.dart';
import 'package:retrail/features/history/history_providers.dart';
import 'package:retrail/map/preview_projection.dart';
import 'package:retrail/map/route_preview_cache.dart';
import 'package:retrail/tracking/location_fix.dart';
import 'package:retrail/tracking/ride_tracker.dart';

/// Headless end-to-end flow test for the core pipeline:
/// **record → save → history → preview**, over an in-memory Drift DB with the
/// existing testable seams (faked render, synthetic GPS track). This is the
/// integration glue the per-spec tests each only touched one side of:
/// `RideTrackerTest` drives recording, `active_ride_controller_test` proves
/// save+preview, `route_preview_cache_test` proves the cache-hit contract — but
/// nothing yet proves a recorded ride flows all the way to `historyItemsProvider`
/// (the real history pipeline over the real DB) and serves a cached preview.
void main() {
  late AppDatabase db;
  late RideTracker tracker;
  late int wallMs; // advancing wall clock so the computed stats are non-trivial

  LocationFix fix(double lat, double lng, int ageNanos) => LocationFix(
    latitude: lat,
    longitude: lng,
    accuracy: 5,
    hasSpeed: true,
    speed: 5, // m/s, above the stationary guard → 18 km/h
    elapsedRealtimeNanos: ageNanos,
  );

  setUp(() {
    db = AppDatabase.memory();
    wallMs = 1700000000000; // a realistic 2023-era epoch, not 1970
    tracker = RideTracker(
      RideRepository(RideDao(db)),
      TrackpointRepository(TrackpointDao(db)),
      const HaversineDistanceCalculator(),
      nowMs: () => wallMs,
      nowNanos: () => 10000000000, // 10 s — keeps the fixes below "fresh"
    );
  });

  tearDown(() async {
    tracker.dispose();
    await db.close();
  });

  test(
    'a recorded ride saves, surfaces in history, and serves a cached preview',
    () async {
      // ── 1. Record: drive RideTracker with a short synthetic track ───────────
      tracker.startTracking();
      await pumpEventQueue(); // let _beginRide insert + capture the active ride id
      expect(tracker.state.isTracking, isTrue);

      wallMs += 30000; // 30 s of riding before the first recorded point
      tracker.onLocationReceived(fix(52.0, 13.0, 8000000000));
      wallMs += 30000; // ~12 m north over the next second
      tracker.onLocationReceived(fix(52.000108, 13.0, 9000000000));

      // Live state advanced: a route was recorded, distance + speed are live.
      expect(tracker.state.trackPoints.length, 2);
      expect(tracker.state.distanceMetres, greaterThan(0));
      expect(tracker.state.speedKmh, closeTo(18.0, 0.01)); // 5 m/s × 3.6

      wallMs += 30000;
      tracker.stopTracking();
      await pumpEventQueue();
      expect(tracker.state.isTracking, isFalse);
      final rideId = tracker.lastCompletedRideId!;

      // ── 2. Save: persist details + generate the preview PNG once ────────────
      final tmp = await Directory.systemTemp.createTemp('e2e_preview');
      addTearDown(() => tmp.delete(recursive: true));

      var renders = 0;
      List<RoutePoint>? capturedRoute;
      final cache = RoutePreviewCache(
        baseDir: tmp,
        render: (points) async {
          renders++;
          capturedRoute = points;
          return Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]); // PNG magic stub
        },
      );
      final controller = ActiveRideController(tracker, cache);

      await controller.saveRide(
        title: 'Sunset cruise',
        comment: 'nice',
        favorite: true,
      );
      await pumpEventQueue(); // saveRideDetails is fire-and-forget — let it land

      // Preview rendered exactly once, with the recorded route, to disk by rideId.
      expect(renders, 1);
      expect(capturedRoute, hasLength(2));
      final previewFile = cache.fileFor(rideId);
      expect(await previewFile.exists(), isTrue);

      // ── 3. History: the REAL pipeline over the REAL DB surfaces the ride ────
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      // Keep the provider subscribed so its Drift stream stays active while we
      // await the first emission.
      final sub = container.listen(historyItemsProvider, (_, _) {});
      addTearDown(sub.close);

      final items = await container.read(historyItemsProvider.future);
      final entries = items.whereType<RideEntryItem>().toList();
      expect(
        entries,
        hasLength(1),
        reason: 'the saved ride appears once in history',
      );

      final entry = entries.single;
      expect(entry.rwt.ride.rideId, rideId);
      expect(entry.rwt.ride.description, 'Sunset cruise');
      expect(entry.rwt.ride.isFavorite, isTrue);
      expect(entry.rwt.trackpoints, hasLength(2));

      // Computed stats are real, not placeholders.
      expect(entry.stats.distanceMetres, greaterThan(0));
      expect(entry.stats.maxSpeedKmh, closeTo(18.0, 0.01));
      expect(entry.stats.durationMs, 90000); // 3 × 30 s of advanced wall clock

      // Date sort groups the ride under a day header.
      expect(items.whereType<DateHeaderItem>(), isNotEmpty);

      // ── 4. Preview: the history card's request is a cache hit, no re-render ──
      final route = <RoutePoint>[
        for (final t in entry.rwt.trackpoints)
          (lat: t.latitude, lng: t.longitude),
      ];
      final servedAgain = await cache.ensurePreview(rideId, route);
      expect(servedAgain.path, previewFile.path);
      expect(renders, 1, reason: 'cached PNG reused — no per-scroll render');
    },
  );
}
