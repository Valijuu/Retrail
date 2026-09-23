import 'package:drift/drift.dart' show Value;

import '../db/app_database.dart';
import '../db/trackpoint_dao.dart';

/// Thin wrapper over [TrackpointDao], mirroring the original Kotlin
/// `TrackpointRepository`.
class TrackpointRepository {
  TrackpointRepository(this._dao);

  final TrackpointDao _dao;

  /// A single ride's trackpoints, on demand (see [TrackpointDao.getByRideId]).
  Stream<List<Trackpoint>> getForRide(int rideId) => _dao.getByRideId(rideId);

  /// Appends one recorded point to a ride. Takes plain values so callers (the
  /// tracker) never touch Drift's companion types. [speedMs] is the provider's
  /// speed in m/s, or null when the fix carried none.
  Future<void> addTrackpoint({
    required int rideId,
    required double latitude,
    required double longitude,
    required int timestampMs,
    double? speedMs,
  }) =>
      _dao.insert(TrackpointsCompanion.insert(
        rideId: rideId,
        latitude: latitude,
        longitude: longitude,
        timestamp: timestampMs,
        speed: Value(speedMs),
      ));
}
