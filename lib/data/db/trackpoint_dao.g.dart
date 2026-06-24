// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trackpoint_dao.dart';

// ignore_for_file: type=lint
mixin _$TrackpointDaoMixin on DatabaseAccessor<AppDatabase> {
  $RidesTable get rides => attachedDatabase.rides;
  $TrackpointsTable get trackpoints => attachedDatabase.trackpoints;
  TrackpointDaoManager get managers => TrackpointDaoManager(this);
}

class TrackpointDaoManager {
  final _$TrackpointDaoMixin _db;
  TrackpointDaoManager(this._db);
  $$RidesTableTableManager get rides =>
      $$RidesTableTableManager(_db.attachedDatabase, _db.rides);
  $$TrackpointsTableTableManager get trackpoints =>
      $$TrackpointsTableTableManager(_db.attachedDatabase, _db.trackpoints);
}
