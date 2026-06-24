// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ride_dao.dart';

// ignore_for_file: type=lint
mixin _$RideDaoMixin on DatabaseAccessor<AppDatabase> {
  $RidesTable get rides => attachedDatabase.rides;
  $TrackpointsTable get trackpoints => attachedDatabase.trackpoints;
  RideDaoManager get managers => RideDaoManager(this);
}

class RideDaoManager {
  final _$RideDaoMixin _db;
  RideDaoManager(this._db);
  $$RidesTableTableManager get rides =>
      $$RidesTableTableManager(_db.attachedDatabase, _db.rides);
  $$TrackpointsTableTableManager get trackpoints =>
      $$TrackpointsTableTableManager(_db.attachedDatabase, _db.trackpoints);
}
