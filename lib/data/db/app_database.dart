import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'ride_dao.dart';
import 'tables.dart';
import 'trackpoint_dao.dart';

part 'app_database.g.dart';

/// Retrail's local SQLite database (Drift). Clean install — schema version 1;
/// the original Room 3→4→5 migrations don't apply (no data migration), so
/// `is_favorite` / `favorited_at` exist from the start.
@DriftDatabase(tables: [Rides, Trackpoints], daos: [RideDao, TrackpointDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// In-memory database for tests.
  AppDatabase.memory() : super(NativeDatabase.memory());

  /// On-device database backed by a file in the app documents directory.
  factory AppDatabase.open() => AppDatabase(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        beforeOpen: (details) async {
          // Required for the trackpoints → rides ON DELETE CASCADE to fire.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'retrail.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
