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
import 'package:retrail/domain/distance_calculator.dart';
import 'package:retrail/features/active_ride/active_ride_controller.dart';
import 'package:retrail/features/active_ride/active_ride_providers.dart';
import 'package:retrail/features/active_ride/active_ride_screen.dart';
import 'package:retrail/features/active_ride/widgets/ride_chrome.dart';
import 'package:retrail/features/follow/route_follow_providers.dart';
import 'package:retrail/features/follow/widgets/follow_chrome.dart';
import 'package:retrail/domain/route_progress.dart';
import 'package:retrail/l10n/app_localizations.dart';
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

  @override
  Future<void> openLocationSettings() async => calls.add('openLocationSettings');
}

/// Records intent calls without touching the DB / preview pipeline.
class RecordingController extends ActiveRideController {
  RecordingController(super.tracker, super.cache);

  final calls = <String>[];
  SaveArgs? saved;

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


class _FixedFollow extends RouteFollowNotifier {
  _FixedFollow(this.initial);
  final RouteFollowState? initial;
  bool stopped = false;
  @override
  RouteFollowState? build() => initial;
  @override
  void stop() {
    stopped = true;
    state = null;
  }
}

RouteFollowState followState({RouteProgress? progress, bool recording = true}) =>
    RouteFollowState(
      track: RouteTrack(const [(lat: 48.0, lng: 11.0), (lat: 48.01, lng: 11.0)]),
      recording: recording,
      progress: progress,
    );

RouteProgress progress({
  double along = 300,
  double remaining = 812,
  double offset = 3,
  bool off = false,
  bool joined = true,
  bool finished = false,
}) =>
    RouteProgress(
        alongM: along,
        remainingM: remaining,
        offsetM: offset,
        isOffRoute: off,
        isFinished: finished,
        hasJoined: joined);

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

  const tracking = RideTrackingState(isTracking: true);

  Future<_FixedFollow> pumpScreen(
    WidgetTester tester, {
    required RideTrackingState state,
    required RouteFollowState? follow,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final notifier = _FixedFollow(follow);
    final router = GoRouter(initialLocation: '/ride', routes: [
      GoRoute(path: '/ride', builder: (c, s) => const ActiveRideScreen()),
      GoRoute(
          path: '/',
          builder: (c, s) => const Scaffold(body: Center(child: Text('home')))),
    ]);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        rideTrackingStateProvider.overrideWith((ref) => Stream.value(state)),
        isOnlineProvider.overrideWith((ref) => Stream.value(true)),
        activeRideControllerProvider.overrideWithValue(controller),
        rideRecordingControllerProvider.overrideWithValue(recording),
        routeFollowProvider.overrideWith(() => notifier),
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
    return notifier;
  }

  testWidgets('without a reference: no remaining line, no follow banner',
      (tester) async {
    await pumpScreen(tester, state: tracking, follow: null);
    expect(find.byType(FollowRemainingLine), findsNothing);
    final map = tester.widget<RideMapArea>(find.byType(RideMapArea));
    expect(map.reference, isNull);
  });

  testWidgets('recording with a reference: map gets it, remaining line shows',
      (tester) async {
    await pumpScreen(tester,
        state: tracking, follow: followState(progress: progress()));
    final map = tester.widget<RideMapArea>(find.byType(RideMapArea));
    expect(map.reference, isNotNull);
    expect(map.referenceProgressM, 300);
    expect(find.text('0.81 km to go'), findsOneWidget);
  });

  testWidgets('before joining: distance-to-route banner', (tester) async {
    await pumpScreen(tester,
        state: tracking,
        follow: followState(
            progress: progress(joined: false, off: true, offset: 250)));
    expect(find.text('0.25 km to the route'), findsOneWidget);
  });

  testWidgets('off route after joining: off-route banner', (tester) async {
    await pumpScreen(tester,
        state: tracking,
        follow: followState(progress: progress(off: true, offset: 45)));
    expect(find.text('Off route — head back to the line'), findsOneWidget);
  });

  testWidgets('a follow-only reference is not shown on the ride screen',
      (tester) async {
    await pumpScreen(tester,
        state: tracking,
        follow: followState(progress: progress(), recording: false));
    expect(find.byType(FollowRemainingLine), findsNothing);
    final map = tester.widget<RideMapArea>(find.byType(RideMapArea));
    expect(map.reference, isNull);
  });

  testWidgets('leaving the ride clears the reference', (tester) async {
    final follow = await pumpScreen(tester,
        state: tracking, follow: followState(progress: progress()));
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(follow.stopped, isTrue);
  });
}
