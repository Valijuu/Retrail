import '../db/app_database.dart';
import '../db/trackpoint_dao.dart';

/// Thin wrapper over [TrackpointDao], mirroring the original Kotlin
/// `TrackpointRepository`.
class TrackpointRepository {
  TrackpointRepository(this._dao);

  final TrackpointDao _dao;

  Stream<List<Trackpoint>> getAll() => _dao.getAll();

  Stream<List<Trackpoint>> getAllByIds(List<int> ids) => _dao.getAllByIds(ids);

  Stream<Trackpoint?> getById(int id) => _dao.getById(id);

  Future<int> insert(TrackpointsCompanion tp) => _dao.insert(tp);

  Future<List<int>> insertAll(List<TrackpointsCompanion> list) =>
      _dao.insertAll(list);

  Future<void> delete(Trackpoint tp) => _dao.deleteRow(tp);

  Future<void> deleteById(int id) => _dao.deleteById(id);
}
