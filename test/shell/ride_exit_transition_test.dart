import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' show LocationPermission;
import 'package:go_router/go_router.dart';
import 'package:retrail/app.dart';
import 'package:retrail/core/connectivity/connectivity_providers.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/db/ride_dao.dart';
import 'package:retrail/data/db/trackpoint_dao.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:retrail/data/repositories/ride_repository.dart';
import 'package:retrail/data/repositories/trackpoint_repository.dart';
import 'package:retrail/domain/distance_calculator.dart';
import 'package:retrail/features/active_ride/active_ride_controller.dart';
import 'package:retrail/features/active_ride/active_ride_providers.dart';
import 'package:retrail/features/profile/profile_providers.dart';
import 'package:retrail/features/shell/routes.dart';
import 'package:retrail/features/timer/countdown_screen.dart';
import 'package:retrail/map/preview_snapshot.dart' show PreviewResult;
import 'package:retrail/map/route_preview_cache.dart';
import 'package:retrail/tracking/location_fix.dart';
import 'package:retrail/tracking/location_permission.dart';
import 'package:retrail/tracking/location_source.dart';
import 'package:retrail/tracking/ride_recording_controller.dart';
import 'package:retrail/tracking/ride_tracker.dart';
import 'package:retrail/tracking/ride_tracking_state.dart';
import 'package:retrail/tracking/tracking_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/home_test_helpers.dart';
import '../support/live_map_stub.dart';

// Test doubles mirroring the pattern in active_ride_screen_test.dart: they
// avoid touching geolocator / Drift so the real nested router (MainShell +
// /timer + /ride as sibling child routes, exactly as app_router.dart wires
// it) can be pumped end-to-end without platform channels or real GPS/DB work.
class _NoopSource implements LocationSource {
  @override
  Stream<bool> get serviceEnabled => const Stream.empty();
  @override
  Stream<LocationFix> get fixes => const Stream.empty();
  @override
  Future<LocationFix?> lastKnown() async => null;
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

class _GrantedPerms implements LocationPermissionService {
  @override
  Future<bool> isPreciseLocation() async => true;
  @override
  Future<void> requestPreciseLocation() async {}
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

class _FakeRecording extends RideRecordingController {
  _FakeRecording(RideTracker tracker)
      : super(
          tracker: tracker,
          source: _NoopSource(),
          permissions: _GrantedPerms(),
          service: _NoopService(),
        );

  @override
  Future<LocationStartAction> prepare() async => LocationStartAction.proceed;
  @override
  Future<LocationStartAction> start() async => LocationStartAction.proceed;
  @override
  Future<void> stop({bool discard = false}) async {}
}

class _FakeActiveRideController extends ActiveRideController {
  _FakeActiveRideController(super.tracker, super.cache);
  @override
  void discardRide() {}
  @override
  Future<void> saveRide({
    String? title,
    String? comment,
    bool favorite = false,
  }) async {}
}

void main() {
  useStubLiveMap();

  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({'onboarding_done': true});
  });

  tearDown(() => db.close());

  /// Pumps the REAL app (real `goRouterProvider`, real nested `/`, `/timer`,
  /// `/ride` routes, real `MainShell`/`CountdownScreen`/`ActiveRideScreen`)
  /// from Home, through the countdown, into an active ride — with only the
  /// GPS/DB-touching seams faked. Leaves the tester right after the
  /// ActiveRideScreen has settled, with the Stop dialog reachable.
  Future<void> pumpToActiveRide(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    db = AppDatabase.memory();
    final prefs = PreferencesRepository(await SharedPreferences.getInstance());
    final tracker = RideTracker(
      RideRepository(RideDao(db)),
      TrackpointRepository(TrackpointDao(db)),
      const HaversineDistanceCalculator(),
    );
    final recording = _FakeRecording(tracker);
    final controller = _FakeActiveRideController(
      tracker,
      RoutePreviewCache(
          baseDir: Directory.systemTemp,
          render: (_, _) async => PreviewResult(Uint8List(0), complete: true)),
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        preferencesRepositoryProvider.overrideWithValue(prefs),
        isOnlineProvider.overrideWith((ref) => Stream.value(true)),
        currentProfilePhotoProvider.overrideWith((ref) => Stream.value(null)),
        recentProfilePhotosProvider.overrideWith((ref) => Stream.value(const [])),
        rideTrackingStateProvider.overrideWith(
            (ref) => Stream.value(const RideTrackingState(isTracking: true))),
        activeRideControllerProvider.overrideWithValue(controller),
        rideRecordingControllerProvider.overrideWithValue(recording),
        ...homeStreamStubs(),
      ],
      child: const RetrailApp(),
    ));
    await tester.pump(); // splash → redirect settles on Home
    await tester.pump(const Duration(milliseconds: 200));

    // Jump straight to the countdown the same way Home's Start-tracking
    // button does (context.go(AppRoutes.timer)) — Home's own permission/
    // online gate isn't what's under test here.
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).go(AppRoutes.timer);
    await tester.pump(); // cross-fade start
    await tester.pump(const Duration(milliseconds: 200)); // let it settle

    // Skip the countdown via its real "Start now" button.
    await tester.tap(find.text('Start now'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // rideEnter settle

    expect(find.text('Stop ride'), findsOneWidget); // on ActiveRideScreen
  }

  /// Steps through the exit transition frame-by-frame and, at every sampled
  /// frame, asserts the invariant the code comments claim: whenever any ride
  /// chrome (e.g. the frozen "Stop ride" stats-panel label) is still on
  /// screen, the black54 scrim must also be up — i.e. the ride screen may
  /// never be visible un-scrimmed once leaving started. Also asserts the
  /// countdown screen never mounts (it must never re-enter the page stack
  /// while popping /ride, per the app_router.dart comment).
  Future<void> assertCleanExitToHome(WidgetTester tester) async {
    const frame = Duration(milliseconds: 8);
    const totalSteps = 40; // 320ms, covers the 220ms reverse + settle slack
    for (var i = 0; i < totalSteps; i++) {
      await tester.pump(frame);

      expect(find.byType(CountdownScreen), findsNothing,
          reason: 'countdown screen re-mounted at step $i (${i * 8}ms)');

      final rideChromeVisible = find.text('Stop ride').evaluate().isNotEmpty;
      final scrimVisible = find
          .byWidgetPredicate(
              (w) => w is ModalBarrier && w.color == Colors.black54)
          .evaluate()
          .isNotEmpty;
      if (rideChromeVisible) {
        expect(scrimVisible, isTrue,
            reason: 'ride chrome visible WITHOUT its scrim at step $i '
                '(${i * 8}ms) — this is the flicker window');
      }
    }
    await tester.pumpAndSettle();
    expect(find.text('Start tracking'), findsOneWidget); // back on Home
  }

  testWidgets(
      'Save: no un-scrimmed ride-screen frame and no countdown re-entry '
      'while popping back to Home', (tester) async {
    await pumpToActiveRide(tester);

    await tester.tap(find.text('Stop ride'));
    await tester.pump();
    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(find.text('How was your ride?'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await assertCleanExitToHome(tester);
  });

  testWidgets(
      'Discard: no un-scrimmed ride-screen frame and no countdown re-entry '
      'while popping back to Home', (tester) async {
    await pumpToActiveRide(tester);

    await tester.tap(find.text('Stop ride'));
    await tester.pump();
    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(find.text('How was your ride?'), findsOneWidget);

    await tester.tap(find.text('Discard ride'));
    await assertCleanExitToHome(tester);
  });
}
