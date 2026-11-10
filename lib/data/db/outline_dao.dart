import 'package:drift/drift.dart';

import 'app_database.dart';
import 'tables.dart';

part 'outline_dao.g.dart';

/// Reads and writes the stored ride outlines (#96).
@DriftAccessor(tables: [Rides, RideOutlines])
class OutlineDao extends DatabaseAccessor<AppDatabase> with _$OutlineDaoMixin {
  OutlineDao(super.db);

  /// Stores or replaces the outline of its ride. Does nothing when the ride
  /// is gone (deleted while the outline was being computed); the check and
  /// the write share one transaction, so no outline row can outlive its ride.
  Future<void> upsert(RideOutlinesCompanion outline) => transaction(() async {
    final rideId = outline.rideId.value;
    final exists = await (select(
      rides,
    )..where((r) => r.rideId.equals(rideId))).getSingleOrNull();
    if (exists == null) return;
    await into(rideOutlines).insertOnConflictUpdate(outline);
  });

  Future<RideOutlineRow?> findByRideId(int rideId) => (select(
    rideOutlines,
  )..where((o) => o.rideId.equals(rideId))).getSingleOrNull();

  Future<List<RideOutlineRow>> getAll() => select(rideOutlines).get();

  /// Ride ids with a route but no outline yet, oldest id first: the work the
  /// background fill still has to do.
  Future<List<int>> rideIdsWithoutOutline() async {
    final query = select(rides)
      ..where(
        (r) =>
            r.hasRoute.equals(true) &
            notExistsQuery(
              select(rideOutlines)..where((o) => o.rideId.equalsExp(r.rideId)),
            ),
      )
      ..orderBy([(r) => OrderingTerm.asc(r.rideId)]);
    return (await query.get()).map((r) => r.rideId).toList();
  }
}
