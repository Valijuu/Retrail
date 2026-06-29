import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:geolocator/geolocator.dart' show LocationPermission;
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/db/ride_dao.dart';
import 'package:retrail/data/db/trackpoint_dao.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:retrail/data/repositories/ride_repository.dart';
import 'package:retrail/data/repositories/trackpoint_repository.dart';
import 'package:retrail/domain/distance_calculator.dart';
import 'package:retrail/domain/stats_aggregation.dart';
import 'package:retrail/features/active_ride/active_ride_controller.dart';
import 'package:retrail/features/active_ride/active_ride_providers.dart';
import 'package:retrail/features/history/history_providers.dart';
import 'package:retrail/features/home/home_providers.dart';
import 'package:retrail/features/home/recent_ride_ui.dart';
import 'package:retrail/map/route_preview_cache.dart';
import 'package:retrail/tracking/location_fix.dart';
import 'package:retrail/tracking/location_permission.dart';
import 'package:retrail/tracking/location_source.dart';
import 'package:retrail/tracking/ride_recording_controller.dart';
import 'package:retrail/tracking/ride_tracker.dart';
import 'package:retrail/tracking/ride_tracking_state.dart';
import 'package:retrail/tracking/tracking_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A controller whose `startRide` is a no-op, for tests that mount `/ride` but
/// don't drive recording — avoids the real ride's periodic elapsed timer.
class NoopActiveRideController extends ActiveRideController {
  NoopActiveRideController(super.tracker, super.cache);
  @override
  void startRide() {}
}

class _NoopSource implements LocationSource {
  @override
  Stream<LocationFix> get fixes => const Stream.empty();
  @override
  Future<LocationFix?> lastKnown() async => null;
}

class _NoopPerms implements LocationPermissionService {
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<void> ensureBackgroundPermission() async {}
  @override
  Future<void> openLocationSettings() async {}
  @override
  Future<void> openAppSettings() async {}
}

class _NoopService implements RideForegroundService {
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> update({
    required bool isPaused,
    required int elapsedSeconds,
    required double distanceMetres,
  }) async {}
  @override
  Future<bool> ensureNotificationPermission() async => true;
}

/// Records the platform-lifecycle calls without touching geolocator / the
/// foreground service, with a settable [prepareResult] so tests can drive the
/// Start-tracking permission gate (the prompt now fires at the button press).
class FakeRecordingController extends RideRecordingController {
  FakeRecordingController(RideTracker tracker)
      : super(
          tracker: tracker,
          source: _NoopSource(),
          permissions: _NoopPerms(),
          service: _NoopService(),
        );

  final calls = <String>[];
  LocationStartAction prepareResult = LocationStartAction.proceed;

  @override
  Future<LocationStartAction> prepare() async {
    calls.add('prepare');
    return prepareResult;
  }

  @override
  Future<LocationStartAction> start() async {
    calls.add('start');
    return LocationStartAction.proceed;
  }

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> openLocationSettings() async => calls.add('openLocationSettings');

  @override
  Future<void> openAppSettings() async => calls.add('openAppSettings');
}

/// A standalone [FakeRecordingController] (its own throwaway tracker) for tests
/// that assert on the Start-tracking gate without wiring up the rest.
FakeRecordingController makeFakeRecording() {
  final db = AppDatabase.memory();
  return FakeRecordingController(RideTracker(
    RideRepository(RideDao(db)),
    TrackpointRepository(TrackpointDao(db)),
    const HaversineDistanceCalculator(),
  ));
}

/// Overrides needed for any test that may navigate to the real `/ride` screen
/// without exercising live recording: a no-op controller (no ride timer), a
/// finite tracking-state stream (the real one never closes), and an existing
/// preview dir (never written). Avoids real file IO, which never completes
/// under `testWidgets`' fake-async.
///
/// Return type is inferred as `List<Override>` (the `Override` type isn't
/// publicly nameable from `flutter_riverpod`).
// ignore: strict_top_level_inference
activeRideTestOverrides(AppDatabase db, {FakeRecordingController? recording}) {
  final dir = Directory.systemTemp;
  final tracker = RideTracker(RideRepository(RideDao(db)),
      TrackpointRepository(TrackpointDao(db)), const HaversineDistanceCalculator());
  return [
    previewCacheDirProvider.overrideWithValue(dir),
    rideTrackingStateProvider
        .overrideWith((ref) => Stream.value(const RideTrackingState())),
    activeRideControllerProvider.overrideWithValue(NoopActiveRideController(
      tracker,
      RoutePreviewCache(baseDir: dir, render: (_, _) async => Uint8List(0)),
    )),
    // The Start-tracking gate (and the active-ride fallback gate) read the real
    // recording controller, which calls geolocator — unavailable under
    // `testWidgets` (MissingPluginException). A fake keeps the gate headless.
    rideRecordingControllerProvider
        .overrideWithValue(recording ?? FakeRecordingController(tracker)),
  ];
}

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
      // The History tab is a PageView neighbor of Home, so any shell-mounting
      // test builds it; keep it off the never-closing Drift `.watch()` stream.
      historyItemsProvider.overrideWith((ref) => Stream.value(const [])),
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
