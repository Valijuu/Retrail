import 'package:drift/drift.dart';

import 'app_database.dart';
import 'tables.dart';

part 'trackpoint_dao.g.dart';

/// Drift port of the original Room `TrackPointDao`.
@DriftAccessor(tables: [Trackpoints])
class TrackpointDao extends DatabaseAccessor<AppDatabase> with _$TrackpointDaoMixin {
  TrackpointDao(super.db);

  Stream<List<Trackpoint>> getAll() => select(trackpoints).watch();

  Stream<List<Trackpoint>> getAllByIds(List<int> ids) =>
      (select(trackpoints)..where((t) => t.trackpointId.isIn(ids))).watch();

  Stream<Trackpoint?> getById(int id) =>
      (select(trackpoints)..where((t) => t.trackpointId.equals(id)))
          .watchSingleOrNull();

  Future<int> insert(TrackpointsCompanion tp) =>
      into(trackpoints).insertOnConflictUpdate(tp);

  Future<List<int>> insertAll(List<TrackpointsCompanion> list) {
    return transaction(() async {
      final ids = <int>[];
      for (final c in list) {
        ids.add(await into(trackpoints).insertOnConflictUpdate(c));
      }
      return ids;
    });
  }

  // Named `deleteRow` to avoid clashing with Drift's `delete(table)` builder.
  Future<void> deleteRow(Trackpoint tp) => delete(trackpoints).delete(tp);

  Future<void> deleteById(int id) =>
      (delete(trackpoints)..where((t) => t.trackpointId.equals(id))).go();
}
