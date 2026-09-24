import 'package:drift/drift.dart';

import 'app_database.dart';
import 'tables.dart';

part 'trackpoint_dao.g.dart';

/// Drift port of the original Room `TrackPointDao`.
@DriftAccessor(tables: [Trackpoints])
class TrackpointDao extends DatabaseAccessor<AppDatabase> with _$TrackpointDaoMixin {
  TrackpointDao(super.db);

  /// A single ride's trackpoints, indexed via `trackpoints_ride_id`. Used to
  /// lazily render a History card's route preview only for the (usually rare,
  /// post-first-render) cache miss — see issue #21 — instead of the History
  /// list eagerly joining every visible ride's trackpoints up front.
  Stream<List<Trackpoint>> getByRideId(int rideId) =>
      (select(trackpoints)..where((t) => t.rideId.equals(rideId))).watch();

  Future<int> insert(TrackpointsCompanion tp) =>
      into(trackpoints).insertOnConflictUpdate(tp);
}
