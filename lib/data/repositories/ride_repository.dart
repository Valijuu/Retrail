import '../db/app_database.dart';
import '../db/ride_dao.dart';
import '../db/ride_with_trackpoints.dart';

/// Returns "now" in epoch milliseconds. Injectable so the favorite timestamp is
/// deterministic in tests (the original used `System.currentTimeMillis()`).
typedef NowMs = int Function();

int _systemNow() => DateTime.now().millisecondsSinceEpoch;

/// Thin wrapper over [RideDao], mirroring the original Kotlin `RideRepository`.
class RideRepository {
  RideRepository(this._dao, {NowMs? now}) : _now = now ?? _systemNow;

  final RideDao _dao;
  final NowMs _now;

  Stream<List<Ride>> getAllRides() => _dao.getAll();

  Stream<List<Ride>> getAllByIds(List<int> rideIds) => _dao.getAllByIds(rideIds);

  Stream<Ride?> getById(int rideId) => _dao.getById(rideId);

  Stream<List<RideWithTrackpoints>> getAllRidesWithTrackpoints() =>
      _dao.getAllRidesWithTrackpoints();

  Stream<RideWithTrackpoints?> getRideWithTrackpointsById(int rideId) =>
      _dao.getRideWithTrackpointsById(rideId);

  Stream<List<RideWithTrackpoints>> getRidesWithTrackpointsBetween(
          int weekStartMs, int weekEndMs) =>
      _dao.getRidesWithTrackpointsBetween(weekStartMs, weekEndMs);

  Stream<List<Ride>> getFavoriteRides() => _dao.getFavoriteRides();

  Stream<List<Ride>> getFilteredFavoriteRides(
          {int startTime = 0, String sortBy = 'date'}) =>
      _dao.getFilteredFavoriteRides(startTime: startTime, sortBy: sortBy);

  Stream<List<Ride>> getFilteredRides(
          {int startTime = 0, String sortBy = 'date', String searchQuery = ''}) =>
      _dao.getFilteredRides(
          startTime: startTime, sortBy: sortBy, searchQuery: searchQuery);

  Future<int> insert(RidesCompanion ride) => _dao.insert(ride);

  Future<List<int>> insertAll(List<RidesCompanion> rides) => _dao.insertAll(rides);

  Future<void> updateEndTime(int rideId, int endTime) =>
      _dao.updateEndTime(rideId, endTime);

  Future<void> updateRideDetails(int rideId, String? description, String? comment) =>
      _dao.updateRideDetails(rideId, description, comment);

  Future<void> updateRideType(int rideId, String? typ) =>
      _dao.updateRideType(rideId, typ);

  /// Sets/clears the favorite flag, stamping `favoritedAt` with "now" when
  /// favoriting and clearing it when un-favoriting (so the home screen can sort
  /// recent favorites by when they were hearted).
  Future<void> updateFavorite(int rideId, bool isFavorite) =>
      _dao.updateFavorite(rideId, isFavorite, isFavorite ? _now() : null);

  Future<void> delete(Ride ride) => _dao.deleteRide(ride);

  Future<void> deleteById(int rideId) => _dao.deleteById(rideId);
}
