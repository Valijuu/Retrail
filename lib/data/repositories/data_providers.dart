import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../db/database_connection.dart';
import '../db/outline_dao.dart';
import '../db/ride_dao.dart';
import '../db/trackpoint_dao.dart';
import 'outline_repository.dart';
import 'preferences_repository.dart';
import 'ride_repository.dart';
import 'trackpoint_repository.dart';

/// Singleton Drift database for the app's lifetime.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = openAppDatabase();
  ref.onDispose(db.close);
  return db;
});

final rideDaoProvider = Provider<RideDao>(
  (ref) => RideDao(ref.watch(appDatabaseProvider)),
);

final trackpointDaoProvider = Provider<TrackpointDao>(
  (ref) => TrackpointDao(ref.watch(appDatabaseProvider)),
);

final outlineDaoProvider = Provider<OutlineDao>(
  (ref) => OutlineDao(ref.watch(appDatabaseProvider)),
);

final outlineRepositoryProvider = Provider<OutlineRepository>(
  (ref) => OutlineRepository(
    ref.watch(outlineDaoProvider),
    ref.watch(trackpointDaoProvider),
  ),
);

final rideRepositoryProvider = Provider<RideRepository>(
  (ref) => RideRepository(
    ref.watch(rideDaoProvider),
    outlines: ref.watch(outlineRepositoryProvider),
  ),
);

final trackpointRepositoryProvider = Provider<TrackpointRepository>(
  (ref) => TrackpointRepository(ref.watch(trackpointDaoProvider)),
);

/// Overridden in `main` with a loaded [SharedPreferences] instance
/// (`PreferencesRepository(await SharedPreferences.getInstance())`).
final preferencesRepositoryProvider = Provider<PreferencesRepository>(
  (ref) => throw UnimplementedError(
    'preferencesRepositoryProvider must be overridden in main()',
  ),
);
