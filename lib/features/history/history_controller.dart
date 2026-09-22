import '../../data/db/app_database.dart';
import '../../data/repositories/ride_repository.dart';
import '../../domain/activity_type.dart';
import '../../map/route_preview_cache.dart';

/// Ride mutations for the history screen. Delegates 1:1 to [RideRepository]
/// (mirroring `RideHistoryViewModel`) and evicts the cached preview PNG when a
/// ride is removed. No repository signature changes.
class HistoryController {
  HistoryController(this._repo, this._cache);

  final RideRepository _repo;
  final RoutePreviewCache _cache;

  Future<void> deleteRide(int rideId) async {
    await _repo.deleteById(rideId);
    await _cache.evict(rideId);
  }

  Future<void> deleteRides(Iterable<int> rideIds) async {
    final ids = rideIds.toList();
    await _repo.deleteByIds(ids);
    // Preview-cache eviction stays per-ID — the cache has no bulk API.
    for (final id in ids) {
      await _cache.evict(id);
    }
  }

  /// Writes title + comment and the (re-assignable) activity type. Editing these
  /// doesn't change the route, so the preview is left intact.
  Future<void> updateRideDetails(
    int rideId,
    String? description,
    String? comment,
    ActivityType? type,
  ) async {
    await _repo.updateRideDetails(rideId, description, comment);
    await _repo.updateRideType(rideId, type?.id);
  }

  Future<void> toggleFavorite(Ride ride) =>
      _repo.updateFavorite(ride.rideId, !ride.isFavorite);
}
