import '../db/app_database.dart';
import '../db/trackpoint_dao.dart';

/// Thin wrapper over [TrackpointDao], mirroring the original Kotlin
/// `TrackpointRepository`.
class TrackpointRepository {
  TrackpointRepository(this._dao);

  final TrackpointDao _dao;

  Future<int> insert(TrackpointsCompanion tp) => _dao.insert(tp);
}
