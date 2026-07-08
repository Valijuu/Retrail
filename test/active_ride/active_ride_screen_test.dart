import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' show LocationPermission;
import 'package:go_router/go_router.dart';
import 'package:retrail/core/connectivity/connectivity_providers.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/db/ride_dao.dart';
import 'package:retrail/data/db/trackpoint_dao.dart';
import 'package:retrail/data/repositories/ride_repository.dart';
import 'package:retrail/data/repositories/trackpoint_repository.dart';
import 'package:retrail/domain/activity_type.dart';
import 'package:retrail/domain/distance_calculator.dart';
import 'package:retrail/features/active_ride/active_ride_controller.dart';
import 'package:retrail/features/active_ride/active_ride_providers.dart';
import 'package:retrail/features/active_ride/active_ride_screen.dart';
import 'package:retrail/l10n/app_localizations.dart';
import 'package:retrail/map/live_map.dart';
import 'package:retrail/map/preview_snapshot.dart' show PreviewResult;
import 'package:retrail/map/route_preview_cache.dart';
import 'package:retrail/tracking/location_fix.dart';
import 'package:retrail/tracking/location_permission.dart';
import 'package:retrail/tracking/location_source.dart';
import 'package:retrail/tracking/ride_recording_controller.dart';
import 'package:retrail/tracking/ride_tracker.dart';
import 'package:retrail/tracking/ride_tracking_state.dart';
import 'package:retrail/tracking/tracking_providers.dart';

import '../support/live_map_stub.dart';

typedef SaveArgs = ({String? title, String? comment, bool favorite});

// Minimal seams so a real RideRecordingController can be constructed; the fake
// overrides start/stop so none are actually exercised.
class _NoopSource implements LocationSource {
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

/// Records the platform-lifecycle calls without touching geolocator / the
/// foreground service.
class FakeRecording extends RideRecordingController {
  FakeRecording(RideTracker tracker)
      : super(
          tracker: tracker,
          source: _NoopSource(),
          permissions: _GrantedPerms(),
          service: _NoopService(),
        );

  final calls = <String>[];
  LocationStartAction next = LocationStartAction.proceed;

  @override
  Future<LocationStartAction> start() async {
    calls.add('start');
    return next;
  }

  @override
  Future<void> stop({bool discard = false}) async =>
      calls.add(discard ? 'stop:discard' : 'stop');
}

/// Records intent calls without touching the DB / preview pipeline.
class RecordingController extends ActiveRideController {
  RecordingController(super.tracker, super.cache);

  final calls = <String>[];
  SaveArgs? saved;

  @override
  void startRide() => calls.add('start');
  @override
  void stopRide() => calls.add('stop');
  @override
  void discardRide() => calls.add('discard');
  @override
  void pauseOrResume(bool isPaused) => calls.add('pauseOrResume:$isPaused');
  @override
  Future<void> saveRide({String? title, String? comment, bool favorite = false}) async {
    saved = (title: title, comment: comment, favorite: favorite);
    calls.add('save');
  }
}

void main() {
  useStubLiveMap();

  late AppDatabase db;
  late RecordingController controller;
  late FakeRecording recording;

  setUp(() {
    db = AppDatabase.memory();
    final tracker = RideTracker(
        RideRepository(RideDao(db)),
        TrackpointRepository(TrackpointDao(db)),
        const HaversineDistanceCalculator());
    controller = RecordingController(
      tracker,
      RoutePreviewCache(
          baseDir: Directory.systemTemp,
          render: (_, _) async => PreviewResult(Uint8List(0), complete: true)),
    );
    recording = FakeRecording(tracker);
  });

  tearDown(() => db.close());

  Future<void> pumpScreen(
    WidgetTester tester, {
    RideTrackingState state = const RideTrackingState(isTracking: true),
    Stream<RideTrackingState>? stateStream,
    bool online = true,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(initialLocation: '/ride', routes: [
      GoRoute(path: '/ride', builder: (c, s) => const ActiveRideScreen()),
      GoRoute(
          path: '/',
          builder: (c, s) => const Scaffold(body: Center(child: Text('home')))),
    ]);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        rideTrackingStateProvider
            .overrideWith((ref) => stateStream ?? Stream.value(state)),
        isOnlineProvider.overrideWith((ref) => Stream.value(online)),
        activeRideControllerProvider.overrideWithValue(controller),
        rideRecordingControllerProvider.overrideWithValue(recording),
      ],
      child: MaterialApp.router(
        theme: buildTheme(Brightness.light),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ));
    await tester.pump(); // post-frame (start) + stream emission
    await tester.pump();
  }

  testWidgets('renders title, Live badge and the stat grid while tracking',
      (tester) async {
    await pumpScreen(
      tester,
      state: const RideTrackingState(
        isTracking: true,
        activityType: ActivityType.longboard,
        speedKmh: 18.0,
        distanceMetres: 1234,
        elapsedSeconds: 65,
      ),
    );
    expect(find.text('Retrail ride'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('18.0 km/h'), findsWidgets); // speed + top speed
    expect(find.text('1.23 km'), findsOneWidget);
    expect(find.text('01:05'), findsOneWidget);
    expect(find.text('Stop ride'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
    expect(recording.calls, contains('start'));
  });

  testWidgets(
      'stats panel shows from the FIRST frame, before tracking has started '
      '(instant blend-in after the timer, even while the map loads)',
      (tester) async {
    await pumpScreen(tester, state: const RideTrackingState()); // not tracking
    expect(find.text('-- km/h'), findsWidgets); // speed + top speed
    expect(find.text('0.00 km'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('Stop ride'), findsOneWidget);
    expect(find.text('Live'), findsNothing); // badge waits for real tracking
  });

  testWidgets('paused state shows Paused badge and Resume', (tester) async {
    await pumpScreen(
      tester,
      state: const RideTrackingState(isTracking: true, isPaused: true),
    );
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
  });

  testWidgets('offline shows the offline banner', (tester) async {
    await pumpScreen(tester, online: false);
    expect(find.text('Offline — map tiles may not be available'), findsOneWidget);
  });

  testWidgets('Stop → confirm opens the summary and calls stopRide',
      (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Stop ride'));
    await tester.pump();
    expect(find.text('Stop ride?'), findsOneWidget);
    await tester.tap(find.text('Stop')); // confirm
    await tester.pump();
    expect(recording.calls, contains('stop'));
    expect(find.text('How was your ride?'), findsOneWidget);
  });

  testWidgets(
      'summary dialog freezes the ride chrome (stats panel + Live badge stay) '
      'and a barrier blocks the screen behind it', (tester) async {
    final states = StreamController<RideTrackingState>();
    addTearDown(states.close);
    await pumpScreen(tester, stateStream: states.stream);
    states.add(const RideTrackingState(isTracking: true, speedKmh: 12));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Stop ride'));
    await tester.pump();
    await tester.tap(find.text('Stop')); // confirm
    await tester.pump();
    // The tracker reports the stop (isTracking flips false) while the summary
    // is open — nothing behind the dialog may change.
    states.add(const RideTrackingState(isTracking: false, speedKmh: 12));
    await tester.pump();
    await tester.pump();

    expect(find.text('How was your ride?'), findsOneWidget);
    expect(find.text('Stop ride'), findsOneWidget); // stats panel frozen
    expect(find.text('Live'), findsOneWidget); // badge frozen
    // A modal scrim swallows taps on everything behind the dialog.
    expect(
      find.byWidgetPredicate(
          (w) => w is ModalBarrier && w.color == Colors.black54),
      findsOneWidget,
    );

    // Saving closes the dialog but the chrome must STAY frozen (panel, badge,
    // scrim) while the exit transition to home plays — no flicker frame.
    await tester.enterText(find.byType(TextField).first, 'Ride');
    await tester.tap(find.text('Save'));
    await tester.pump(); // dialog closed, navigation started — mid-transition
    expect(find.text('How was your ride?'), findsNothing);
    expect(find.text('Stop ride'), findsOneWidget); // panel still there
    expect(find.text('Live'), findsOneWidget); // badge still there
    expect(
      find.byWidgetPredicate(
          (w) => w is ModalBarrier && w.color == Colors.black54),
      findsOneWidget, // scrim kept up through the exit
    );
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets(
      'summary dialog rises above the keyboard without overflowing, while '
      'the ride layout behind stays untouched', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Stop ride'));
    await tester.pump();
    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(find.text('How was your ride?'), findsOneWidget);

    // Keyboard opens for the title/comment inputs. Dialog avoids the insets
    // itself via an AnimatedPadding — pump past its animation.
    tester.view.viewInsets = const FakeViewPadding(bottom: 500);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull); // no "bottom overflowed" banner
    // The dialog content is lifted above the keyboard (900 - 500 = 400)…
    expect(tester.getRect(find.text('How was your ride?')).bottom,
        lessThanOrEqualTo(400));
    // resizeToAvoidBottomInset: false — the map area behind keeps its size.
    expect(find.text('Stop ride'), findsOneWidget); // panel not squeezed away

    // …and stays fully usable: content scrolls inside the card, Save is
    // reachable and completes the flow (regression: double inset padding once
    // shoved the dialog off-screen and made it untappable).
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('summary Save persists details and navigates home',
      (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Stop ride'));
    await tester.pump();
    await tester.tap(find.text('Stop'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'Evening roll');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(controller.saved?.title, 'Evening roll');
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('summary Discard calls discardRide and navigates home',
      (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Stop ride'));
    await tester.pump();
    await tester.tap(find.text('Stop'));
    await tester.pump();
    await tester.tap(find.text('Discard ride'));
    await tester.pumpAndSettle();
    expect(controller.calls, contains('discard'));
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets(
      'back with the stop dialog open dismisses it instead of stacking the '
      'discard dialog on top', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Stop ride'));
    await tester.pump();
    expect(find.text('Stop ride?'), findsOneWidget);

    // System back: closes the stop dialog, does NOT add another (the app-bar
    // arrow is behind the modal barrier, so only system back reaches here).
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Stop ride?'), findsNothing);
    expect(find.text('Discard ride?'), findsNothing);

    // Back again, with no dialog open → discard confirmation as usual.
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Discard ride?'), findsOneWidget);
  });

  testWidgets('back → confirm discard → dispose stops and discards the ride',
      (tester) async {
    await pumpScreen(tester);
    // Tap the app-bar back arrow while tracking → discard-confirm dialog.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    expect(find.text('Discard ride?'), findsOneWidget);
    await tester.tap(find.text('Discard')); // confirm → stop:discard → go home
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    // stop:discard fires eagerly in onConfirm (before navigation) so that
    // isTrackingProvider is false before the home screen is interactive —
    // deferring it to dispose() left a window during GoRouter's exit animation
    // where "Start Tracking" could skip the timer.
    expect(recording.calls, contains('stop:discard'));
  });

  testWidgets('Pause button calls pauseOrResume', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Pause'));
    expect(controller.calls, contains('pauseOrResume:false'));
  });

  testWidgets('recenter FAB appears after a map gesture and re-follows',
      (tester) async {
    await pumpScreen(tester);
    expect(find.byIcon(Icons.refresh), findsNothing);

    // Simulate the LiveMap reporting a user gesture.
    final liveMap = tester.widget<LiveMap>(find.byType(LiveMap));
    liveMap.onGesture!();
    await tester.pump();
    expect(find.byIcon(Icons.refresh), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();
    expect(find.byIcon(Icons.refresh), findsNothing);
  });
}
