import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:retrail/map/route_preview_cache.dart';
import 'package:retrail/tracking/ride_tracker.dart';
import 'package:retrail/tracking/ride_tracking_state.dart';
import 'package:retrail/tracking/tracking_providers.dart';

typedef SaveArgs = ({String? title, String? comment, bool favorite});

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
  late AppDatabase db;
  late RecordingController controller;

  setUp(() {
    db = AppDatabase.memory();
    controller = RecordingController(
      RideTracker(RideRepository(RideDao(db)), TrackpointRepository(TrackpointDao(db)),
          const HaversineDistanceCalculator()),
      RoutePreviewCache(
          baseDir: Directory.systemTemp, render: (_) async => Uint8List(0)),
    );
  });

  tearDown(() => db.close());

  Future<void> pumpScreen(
    WidgetTester tester, {
    RideTrackingState state = const RideTrackingState(isTracking: true),
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
        rideTrackingStateProvider.overrideWith((ref) => Stream.value(state)),
        isOnlineProvider.overrideWith((ref) => Stream.value(online)),
        activeRideControllerProvider.overrideWithValue(controller),
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
    expect(controller.calls, contains('start'));
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
    expect(controller.calls, contains('stop'));
    expect(find.text('How was your ride?'), findsOneWidget);
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

  testWidgets('back → confirm discard → dispose stops and discards the ride',
      (tester) async {
    await pumpScreen(tester);
    // Tap the app-bar back arrow while tracking → discard-confirm dialog.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    expect(find.text('Discard ride?'), findsOneWidget);
    await tester.tap(find.text('Discard')); // confirm → go home → dispose
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    // dispose() ran without throwing on the captured controller.
    expect(controller.calls, contains('stop'));
    expect(controller.calls, contains('discard'));
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
