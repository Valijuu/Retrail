import 'package:drift/drift.dart';

/// Mirrors the original Room `rides` table (entity `Ride`).
@DataClassName('Ride')
class Rides extends Table {
  IntColumn get rideId => integer().autoIncrement()();
  TextColumn get description => text().nullable()();
  TextColumn get typ => text().nullable()();
  IntColumn get startTime => integer().nullable()();
  IntColumn get endTime => integer().nullable()();
  IntColumn get date => integer().nullable()();
  TextColumn get comment => text().nullable()();
  BoolColumn get isFavorite =>
      boolean().named('is_favorite').withDefault(const Constant(false))();
  IntColumn get favoritedAt => integer().named('favorited_at').nullable()();

  // Denormalized [RideStats] fields (lib/domain/ride_stats.dart), written once
  // at ride finalization (RideRepository.updateEndTime) instead of recomputed
  // from the full trackpoint list on every History list rebuild. Null means
  // "not yet computed" (an in-progress ride, or a pre-migration row before
  // the v2 backfill runs) — callers fall back to computeRideStats in that case.
  RealColumn get distanceMetres => real().named('distance_metres').nullable()();
  IntColumn get durationMs => integer().named('duration_ms').nullable()();
  RealColumn get avgSpeedKmh => real().named('avg_speed_kmh').nullable()();
  RealColumn get maxSpeedKmh => real().named('max_speed_kmh').nullable()();

  // Whether this ride has any recorded trackpoints, written once at
  // finalization alongside the stats above (see RideRepository.updateEndTime).
  // Lets the History list (RideDao.getRidesInRange) decide whether a card has
  // a route to preview/navigate to WITHOUT joining trackpoints for every
  // visible ride on every rebuild — see issue #21. Defaults false; an
  // in-progress ride (no endTime yet) reads as routeless until finalized.
  BoolColumn get hasRoute =>
      boolean().named('has_route').withDefault(const Constant(false))();
}

/// Mirrors the original Room `trackpoints` table (entity `Trackpoint`).
/// `rideId` is a foreign key onto [Rides] with ON DELETE CASCADE.
@DataClassName('Trackpoint')
@TableIndex(name: 'trackpoints_ride_id', columns: {#rideId})
class Trackpoints extends Table {
  IntColumn get trackpointId => integer().autoIncrement()();
  IntColumn get rideId =>
      integer().references(Rides, #rideId, onDelete: KeyAction.cascade)();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  IntColumn get timestamp => integer()();
  RealColumn get speed => real().nullable()();
}
