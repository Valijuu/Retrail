import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/db/ride_dao.dart';
import 'package:retrail/data/db/trackpoint_dao.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/data/repositories/ride_repository.dart';
import 'package:retrail/data/repositories/trackpoint_repository.dart';
import 'package:retrail/domain/distance_calculator.dart';
import 'package:retrail/features/follow/route_follow_providers.dart';
import 'package:retrail/tracking/ride_tracker.dart';
import 'package:retrail/tracking/tracking_providers.dart';

/// Spec 20: the default writer stores a stopped repeat's link.
void main() {
  late AppDatabase db;
  late RideRepository repo;
  late RideTracker tracker;
  late ProviderContainer c;

  setUp(() {
    db = AppDatabase.memory();
    repo = RideRepository(RideDao(db));
    tracker = RideTracker(
      repo,
      TrackpointRepository(TrackpointDao(db)),
      const HaversineDistanceCalculator(),
    );
    c = ProviderContainer(
      overrides: [
        rideRepositoryProvider.overrideWithValue(repo),
        rideTrackerProvider.overrideWithValue(tracker),
      ],
    );
  });
  tearDown(() async {
    c.dispose();
    tracker.dispose();
    await db.close();
  });

  Future<int> recordAndStop() async {
    tracker.startTracking();
    await pumpEventQueue();
    tracker.stopTracking();
    await pumpEventQueue();
    return tracker.lastCompletedRideId!;
  }

  test('links the just-stopped ride to its original', () async {
    final original = await repo.startRide(startedAtMs: 1);
    final rideId = await recordAndStop();

    c.read(followLinkWriterProvider)((
      originalId: original,
      coverage: 0.95,
      routeTimeMs: 840000,
    ));
    await pumpEventQueue();

    final ride = await repo.findById(rideId);
    expect(ride!.followedRideId, original);
    expect(ride.followCoverage, 0.95);
    expect(ride.followRouteMs, 840000);
  });

  test('an original deleted during the ride is no error', () async {
    final rideId = await recordAndStop();

    c.read(followLinkWriterProvider)((
      originalId: 999,
      coverage: 1,
      routeTimeMs: null,
    ));
    await pumpEventQueue();

    expect((await repo.findById(rideId))!.followedRideId, isNull);
  });
}
