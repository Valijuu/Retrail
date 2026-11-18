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
    // A rewrite keeps the row and raises its revision (#111).
    await into(rideOutlines).insert(
      outline,
      onConflict: DoUpdate.withExcluded(
        (old, excluded) => RideOutlinesCompanion.custom(
          polyline: excluded.polyline,
          south: excluded.south,
          west: excluded.west,
          north: excluded.north,
          east: excluded.east,
          revision: old.revision + const Constant(1),
        ),
      ),
    );
  });

  /// The outlines of [rideIds] only; unknown ids are skipped.
  Future<List<RideOutlineRow>> getByRideIds(Iterable<int> rideIds) =>
      (select(rideOutlines)..where((o) => o.rideId.isIn(rideIds))).get();

  /// Ride id → revision of every outline row, re-emitted when one is added,
  /// rewritten or removed (#111). Reads the id and revision only, never the
  /// polyline.
  Stream<Map<int, int>> watchOutlineRevisions() {
    final query = selectOnly(rideOutlines)
      ..addColumns([rideOutlines.rideId, rideOutlines.revision]);
    return query.watch().map(
      (rows) => {
        for (final row in rows)
          row.read(rideOutlines.rideId)!: row.read(rideOutlines.revision)!,
      },
    );
  }

  /// Ride ids with a route but no outline yet, oldest id first: the work the
  /// background fill still has to do. [limit] caps the list, so a fill step
  /// does not list the whole backlog (#112). Reads the id column only.
  Future<List<int>> rideIdsWithoutOutline({int? limit}) async {
    final query = selectOnly(rides)
      ..addColumns([rides.rideId])
      ..where(
        rides.hasRoute.equals(true) &
            notExistsQuery(
              select(rideOutlines)
                ..where((o) => o.rideId.equalsExp(rides.rideId)),
            ),
      )
      ..orderBy([OrderingTerm.asc(rides.rideId)]);
    if (limit != null) query.limit(limit);
    return [for (final row in await query.get()) row.read(rides.rideId)!];
  }
}
