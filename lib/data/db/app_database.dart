import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../../domain/distance_calculator.dart';
import '../../domain/ride_stats.dart';
import 'ride_dao.dart';
import 'tables.dart';
import 'trackpoint_dao.dart';

part 'app_database.g.dart';

/// Retrail's local SQLite database (Drift). Clean install — schema version 1;
/// the original Room 3→4→5 migrations don't apply (no data migration), so
/// `is_favorite` / `favorited_at` exist from the start.
@DriftDatabase(tables: [Rides, Trackpoints], daos: [RideDao, TrackpointDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// In-memory database for tests.
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v2: denormalized RideStats columns (see tables.dart) — computed
            // once at ride-finalization from here on (RideRepository.
            // updateEndTime), instead of recomputed from the full trackpoint
            // list on every History rebuild.
            await m.addColumn(rides, rides.distanceMetres);
            await m.addColumn(rides, rides.durationMs);
            await m.addColumn(rides, rides.avgSpeedKmh);
            await m.addColumn(rides, rides.maxSpeedKmh);
          }
          if (from < 3) {
            // v3: has_route — lets the History list query rides without
            // joining trackpoints (see issue #21).
            await m.addColumn(rides, rides.hasRoute);
          }
          if (from < 3) {
            // Backfill existing rows so old rides get the same fast path
            // immediately rather than falling back to computeRideStats /
            // showing "no route" forever. Harmless to redo the v2 stats math
            // here too on a hypothetical v2 install — same source data, same
            // (idempotent) result.
            await _backfillStatsAndRoute(this);
          }
        },
        beforeOpen: (details) async {
          // Required for the trackpoints → rides ON DELETE CASCADE to fire.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

/// Computes and stores [RideStats] + [hasRoute] for every existing ride,
/// once, as part of the v3 migration. Reuses [computeRideStats] so the
/// backfilled values are byte-for-byte what the app already displayed — this
/// only changes *when* they're computed, not the math.
Future<void> _backfillStatsAndRoute(AppDatabase db) async {
  const calc = HaversineDistanceCalculator();
  final rides = await db.rideDao.getAllRidesWithTrackpoints().first;
  for (final rwt in rides) {
    final stats = computeRideStats(rwt, calc);
    await db.rideDao.updateStats(
      rwt.ride.rideId,
      distanceMetres: stats.distanceMetres,
      durationMs: stats.durationMs,
      avgSpeedKmh: stats.avgSpeedKmh,
      maxSpeedKmh: stats.maxSpeedKmh,
      hasRoute: rwt.trackpoints.isNotEmpty,
    );
  }
}
