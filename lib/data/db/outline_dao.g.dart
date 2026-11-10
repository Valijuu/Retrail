// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'outline_dao.dart';

// ignore_for_file: type=lint
mixin _$OutlineDaoMixin on DatabaseAccessor<AppDatabase> {
  $RidesTable get rides => attachedDatabase.rides;
  $RideOutlinesTable get rideOutlines => attachedDatabase.rideOutlines;
  OutlineDaoManager get managers => OutlineDaoManager(this);
}

class OutlineDaoManager {
  final _$OutlineDaoMixin _db;
  OutlineDaoManager(this._db);
  $$RidesTableTableManager get rides =>
      $$RidesTableTableManager(_db.attachedDatabase, _db.rides);
  $$RideOutlinesTableTableManager get rideOutlines =>
      $$RideOutlinesTableTableManager(_db.attachedDatabase, _db.rideOutlines);
}
