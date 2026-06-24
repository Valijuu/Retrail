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
