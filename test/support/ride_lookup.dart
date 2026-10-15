import 'package:collection/collection.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/db/ride_dao.dart';
import 'package:retrail/data/repositories/ride_repository.dart';

/// Test-only *watching* single-ride lookups. Production only needs a one-shot
/// read ([RideDao.findById]), so these streams live here rather than as dead
/// DAO/repository API.
extension RideRepositoryLookup on RideRepository {
  Stream<Ride?> getById(int rideId) => getAllRides().map(
    (rides) => rides.firstWhereOrNull((r) => r.rideId == rideId),
  );
}

extension RideDaoLookup on RideDao {
  Stream<Ride?> getById(int rideId) => getAll().map(
    (rides) => rides.firstWhereOrNull((r) => r.rideId == rideId),
  );
}
