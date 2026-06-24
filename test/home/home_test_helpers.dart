import 'package:drift/drift.dart' show Value;
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:retrail/domain/stats_aggregation.dart';
import 'package:retrail/features/home/home_providers.dart';
import 'package:retrail/features/home/recent_ride_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overrides the Drift `.watch()`-backed Home providers with finite
/// `Stream.value` streams. Drift's broadcast `.watch()` stream never closes,
/// which deadlocks `flutter_test`'s fake-async event loop when a widget
/// subscribes to it. Tests that mount Home use these stubs and seed data via
/// dedicated provider overrides where they need non-empty content.
///
/// Return type is intentionally inferred as `List<Override>` — the `Override`
/// type isn't publicly nameable from `flutter_riverpod`, so it can't be written
/// explicitly here.
// ignore: strict_top_level_inference
homeStreamStubs({
  List<RecentRideUi> recent = const [],
  List<RecentRideUi> favorites = const [],
  WeeklyStats weekly = const WeeklyStats.zero(),
  WeeklyStats daily = const WeeklyStats.zero(),
  WeeklyStats yearly = const WeeklyStats.zero(),
}) =>
    [
      recentRidesProvider.overrideWith((ref) => Stream.value(recent)),
      favoriteRidesProvider.overrideWith((ref) => Stream.value(favorites)),
      weeklyStatsProvider.overrideWith((ref) => Stream.value(weekly)),
      dailyStatsProvider.overrideWith((ref) => Stream.value(daily)),
      yearlyStatsProvider.overrideWith((ref) => Stream.value(yearly)),
    ];

class HomeEnv {
  HomeEnv(this.db, this.prefs);
  final AppDatabase db;
  final PreferencesRepository prefs;
}

Future<HomeEnv> buildHomeEnv({Map<String, Object> initialPrefs = const {}}) async {
  SharedPreferences.setMockInitialValues(initialPrefs);
  final prefs = PreferencesRepository(await SharedPreferences.getInstance());
  return HomeEnv(AppDatabase.memory(), prefs);
}

Future<int> insertRide(
  AppDatabase db, {
  String? description,
  int? startTime,
  int? endTime,
  int? date,
  bool favorite = false,
  int? favoritedAt,
}) async {
  final id = await db.rideDao.insert(RidesCompanion.insert(
    description: Value(description),
    startTime: Value(startTime),
    endTime: Value(endTime),
    date: Value(date ?? startTime),
  ));
  if (favorite) await db.rideDao.updateFavorite(id, true, favoritedAt ?? date);
  return id;
}

Future<void> addPoint(AppDatabase db, int rideId, double lat, double lng) =>
    db.trackpointDao.insert(TrackpointsCompanion.insert(
        rideId: rideId, latitude: lat, longitude: lng, timestamp: 0));
