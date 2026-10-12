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

  /// Writes title + comment, the (re-assignable) activity type and the
  /// favorite flag (#76). Editing these doesn't change the route, so the
  /// preview is left intact. The flag is only written when it changed, so an
  /// unchanged favorite keeps its `favoritedAt` (Home's recent-favorites order).
  Future<void> updateRideDetails(
    Ride ride,
    String? description,
    String? comment,
    ActivityType? type,
    bool favorite,
  ) async {
    await _repo.updateRideDetails(ride.rideId, description, comment);
    await _repo.updateRideType(ride.rideId, type?.id);
    if (favorite != ride.isFavorite) {
      await _repo.updateFavorite(ride.rideId, favorite);
    }
  }

  Future<void> toggleFavorite(Ride ride) =>
      _repo.updateFavorite(ride.rideId, !ride.isFavorite);
}
