import 'package:drift/drift.dart' show Value;

import '../../domain/distance_calculator.dart';
import '../../domain/ride_stats.dart';
import '../db/app_database.dart';
import '../db/ride_dao.dart';
import '../db/ride_with_trackpoints.dart';

/// Returns "now" in epoch milliseconds. Injectable so the favorite timestamp is
/// deterministic in tests (the original used `System.currentTimeMillis()`).
typedef NowMs = int Function();

int _systemNow() => DateTime.now().millisecondsSinceEpoch;

/// Thin wrapper over [RideDao], mirroring the original Kotlin `RideRepository`.
class RideRepository {
  RideRepository(this._dao, {NowMs? now, DistanceCalculator? calc})
      : _now = now ?? _systemNow,
        _calc = calc ?? const HaversineDistanceCalculator();

  final RideDao _dao;
  final NowMs _now;
  final DistanceCalculator _calc;

  Stream<List<Ride>> getAllRides() => _dao.getAll();

  Stream<Ride?> getById(int rideId) => _dao.getById(rideId);

  Stream<List<RideWithTrackpoints>> getAllRidesWithTrackpoints() =>
      _dao.getAllRidesWithTrackpoints();

  Stream<List<RideWithTrackpoints>> getRidesWithTrackpointsBetween(
          int weekStartMs, int weekEndMs) =>
      _dao.getRidesWithTrackpointsBetween(weekStartMs, weekEndMs);

  /// Drives the History list — rides only, no trackpoints join (see
  /// issue #21 / [RideDao.getRidesInRange]).
  Stream<List<Ride>> getRidesInRange({int? startMs, int? endMs}) =>
      _dao.getRidesInRange(startMs: startMs, endMs: endMs);

  /// A single ride with its trackpoints, on demand (detail dialog, or a
  /// History card's not-yet-cached route preview — see issue #21).
  Stream<RideWithTrackpoints?> getRideWithTrackpointsById(int rideId) =>
      _dao.getRideWithTrackpointsById(rideId);

  /// Opens a ride row at recording start and returns its id. Takes plain
  /// values so callers (the tracker) never touch Drift's companion types.
  Future<int> startRide({String? activityTypeId, required int startedAtMs}) =>
      _dao.insert(RidesCompanion.insert(
        typ: Value(activityTypeId),
        startTime: Value(startedAtMs),
        date: Value(startedAtMs),
      ));

  /// Stamps the end time AND caches [RideStats] + hasRoute onto the row
  /// (distance, duration, avg/max speed, whether it has any trackpoints) —
  /// computed once here via [computeRideStats], so History reads them
  /// straight off the row instead of recomputing a full Haversine sum (and
  /// joining every trackpoint) on every list rebuild. A ride with no
  /// trackpoints yet (the finalize-race edge case in RideTracker) still gets
  /// a zeroed stats row rather than staying null forever.
  Future<void> updateEndTime(int rideId, int endTime) async {
    await _dao.updateEndTime(rideId, endTime);
    final rwt = await _dao.getRideWithTrackpointsById(rideId).first;
    if (rwt == null) return;
    final stats = computeRideStats(rwt, _calc);
    await _dao.updateStats(
      rideId,
      distanceMetres: stats.distanceMetres,
      durationMs: stats.durationMs,
      avgSpeedKmh: stats.avgSpeedKmh,
      maxSpeedKmh: stats.maxSpeedKmh,
      hasRoute: rwt.trackpoints.isNotEmpty,
    );
  }

  Future<void> updateRideDetails(int rideId, String? description, String? comment) =>
      _dao.updateRideDetails(rideId, description, comment);

  Future<void> updateRideType(int rideId, String? typ) =>
      _dao.updateRideType(rideId, typ);

  /// Sets/clears the favorite flag, stamping `favoritedAt` with "now" when
  /// favoriting and clearing it when un-favoriting (so the home screen can sort
  /// recent favorites by when they were hearted).
  Future<void> updateFavorite(int rideId, bool isFavorite) =>
      _dao.updateFavorite(rideId, isFavorite, isFavorite ? _now() : null);

  Future<void> deleteById(int rideId) => _dao.deleteById(rideId);

  Future<void> deleteByIds(List<int> rideIds) => _dao.deleteByIds(rideIds);
}
