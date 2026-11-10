import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show FlutterExceptionHandler;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' show LocationPermission;
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:retrail/app.dart';
import 'package:retrail/core/connectivity/connectivity_providers.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:retrail/features/active_ride/active_ride_providers.dart';
import 'package:retrail/features/history/widgets/ride_preview_thumbnail.dart';
import 'package:retrail/features/shell/app_router.dart';
import 'package:retrail/features/shell/routes.dart';
import 'package:retrail/features/timer/countdown_providers.dart';
import 'package:retrail/l10n/app_localizations.dart';
import 'package:retrail/tracking/countdown_announcer.dart';
import 'package:retrail/tracking/location_fix.dart';
import 'package:retrail/tracking/location_source.dart';
import 'package:retrail/tracking/ride_recording_controller.dart';
import 'package:retrail/tracking/tracking_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App Store screenshots (#87), run by `tool/ios_screenshots.sh` in the iOS
/// Simulator: drives the real app in-process and, per motive, prints
/// `RETRAIL_SHOT <name>` and waits until the script took the shot with
/// `xcrun simctl io screenshot` (an ack file in Documents/shot_ack). The
/// script, not `binding.takeScreenshot`, captures, because the map is a
/// native platform view.
///
/// The rides come from the demo database (tool/demo_rides, invented routes on
/// Tempelhofer Feld) that the script copies into Documents when the test
/// prints `RETRAIL_SETUP`; each motive works on its own copy. GPS is replayed
/// from the newest demo ride, so no real location data is involved.
///
///   --dart-define=RETRAIL_SHOT_LANG=en|de
///   --dart-define=RETRAIL_SHOT_THEME=light|dark
///   --dart-define=RETRAIL_SHOTS=02_history,07_track (default: all)
const _lang = String.fromEnvironment('RETRAIL_SHOT_LANG', defaultValue: 'en');
const _theme = String.fromEnvironment(
  'RETRAIL_SHOT_THEME',
  defaultValue: 'light',
);
const _shots = String.fromEnvironment('RETRAIL_SHOTS');

bool _wanted(String name) => _shots.isEmpty || _shots.split(',').contains(name);

final _l10n = lookupAppLocalizations(Locale(_lang));

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Frames as on a real phone (animations, map), not only on pump().
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  late Directory docs;
  late File demoDb;

  setUpAll(() async {
    await initializeDateFormatting();
    docs = await getApplicationDocumentsDirectory();
    demoDb = File(p.join(docs.path, 'store_demo.sqlite'));
    await _handshake('RETRAIL_SETUP', 'setup', const Duration(minutes: 2));
    if (!demoDb.existsSync()) {
      throw StateError('demo database not copied to ${demoDb.path}');
    }
  });

  testWidgets(
    '02_history, 03_detail, 04_best_time',
    (tester) async {
      final app = await _App.start(tester, docs, demoDb);
      await _openHistory(tester);
      // Route previews render from map tiles over the network.
      await _wait(tester, const Duration(seconds: 15));
      await _shot(tester, '02_history');
      // Scrolled to the winter rides (the Schroll ski run) for the store shot.
      await tester.drag(
        find.byType(RidePreviewThumbnail).first,
        const Offset(0, -420),
      );
      await _wait(tester, const Duration(seconds: 6));
      await _shot(tester, '02_history_winter');
      await tester.drag(
        find.byType(RidePreviewThumbnail).first,
        const Offset(0, 420),
      );
      await _wait(tester, const Duration(seconds: 2));

      await tester.tap(find.byType(RidePreviewThumbnail).first);
      await _wait(tester, const Duration(seconds: 6));
      await _shot(tester, '03_detail');
      await tester.tap(find.text(_l10n.actionClose).last);
      await _wait(tester, const Duration(seconds: 1));

      await tester.tap(find.text(_l10n.chipFollowed).first);
      await _wait(tester, const Duration(seconds: 4));
      await _shot(tester, '04_best_time');
      await app.close();
    },
    skip:
        !_wanted('02_history') &&
        !_wanted('02_history_winter') &&
        !_wanted('03_detail') &&
        !_wanted('04_best_time'),
  );

  testWidgets('05_follow', (tester) async {
    final app = await _App.start(tester, docs, demoDb);
    await app.source.useNewestRide(app.container, fastUntil: 0.45);
    await _openHistory(tester);
    await _wait(tester, const Duration(seconds: 3));
    await tester.tap(find.byType(RidePreviewThumbnail).first);
    await _wait(tester, const Duration(seconds: 2));
    await tester.tap(find.text(_l10n.followRouteAction));
    await _wait(tester, const Duration(seconds: 1));
    await tester.tap(find.text(_l10n.followRouteJustFollow));
    // The fast replay rides 45 % of the route, then the map settles.
    await _wait(tester, const Duration(seconds: 25));
    await _shot(tester, '05_follow');
    await app.close();
  }, skip: !_wanted('05_follow'));

  testWidgets('08_activities', (tester) async {
    final app = await _App.start(tester, docs, demoDb, onboardingDone: false);
    app.container.read(goRouterProvider).go(AppRoutes.activityPicker);
    await _wait(tester, const Duration(seconds: 3));
    await _shot(tester, '08_activities');
    await app.close();
  }, skip: !_wanted('08_activities'));

  // Last: the ride keeps writing trackpoints until the app is torn down.
  testWidgets(
    '06_countdown, 07_track',
    (tester) async {
      final app = await _App.start(tester, docs, demoDb);
      await app.source.useNewestRide(app.container);
      await _wait(tester, const Duration(seconds: 3));
      await tester.tap(find.text(_l10n.homeStartTracking));
      if (_wanted('06_countdown')) {
        // The host takes the shot 1 to 15 s after the marker (run
        // 42366838171), while the countdown keeps ticking: a shot during the
        // 320 ms digit roll shows two digits. "+5 sec." restarts the ticker,
        // so right after its roll the digit stands for a moment; the shot
        // freezes that frame until the host has taken it.
        await _wait(tester, const Duration(milliseconds: 4200));
        await tester.tap(find.text(_l10n.timerAddFiveSec));
        await _wait(tester, const Duration(milliseconds: 400));
        await _shot(
          tester,
          '06_countdown',
          settle: Duration.zero,
          freeze: true,
        );
      } else {
        await _wait(tester, const Duration(seconds: 2));
        await tester.tap(find.text(_l10n.timerStartNow));
      }
      if (_wanted('07_track')) {
        // Distance only counts after the start is confirmed (about 10 s).
        await _wait(tester, const Duration(seconds: 55));
        await _shot(tester, '07_track');
      }
      try {
        await app.container
            .read(rideRecordingControllerProvider)
            .stop(discard: true);
      } catch (_) {}
      await _wait(tester, const Duration(seconds: 1));
      await app.close();
    },
    skip: !_wanted('06_countdown') && !_wanted('07_track'),
  );
}

Future<void> _openHistory(WidgetTester tester) async {
  await _wait(tester, const Duration(seconds: 2));
  await tester.tap(find.byIcon(Icons.list));
  await _wait(tester, const Duration(seconds: 1));
}

/// One app instance on its own copy of the demo database.
class _App {
  _App(this.tester, this.container, this.db, this.source, this._onError);

  final WidgetTester tester;
  final FlutterExceptionHandler? _onError;

  final ProviderContainer container;
  final AppDatabase db;
  final _ReplaySource source;

  static int _copies = 0;

  static Future<_App> start(
    WidgetTester tester,
    Directory docs,
    File demoDb, {
    bool onboardingDone = true,
  }) async {
    SharedPreferences.setMockInitialValues({
      'user_name': PreferencesRepository.defaultUserName,
      'onboarding_done': onboardingDone,
      'app_language': _lang,
      'theme_mode': _theme,
      'battery_hint_dismissed': true,
    });
    final prefs = PreferencesRepository(await SharedPreferences.getInstance());
    final copy = File(p.join(docs.path, 'store_shot_${_copies++}.sqlite'));
    await demoDb.copy(copy.path);
    final db = AppDatabase(NativeDatabase.createInBackground(copy));
    final previews = Directory(p.join(docs.path, 'store_shot_previews'))
      ..createSync(recursive: true);
    final source = _ReplaySource();
    final container = ProviderContainer(
      overrides: [
        preferencesRepositoryProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        previewCacheDirProvider.overrideWithValue(previews),
        locationSourceProvider.overrideWithValue(source),
        locationPermissionServiceProvider.overrideWithValue(_Granted()),
        // No Live Activity in the shots (the lock screen is out of scope).
        rideForegroundServiceProvider.overrideWithValue(_NoService()),
        countdownAnnouncerProvider.overrideWithValue(_Silent()),
        isOnlineProvider.overrideWith((ref) => Stream.value(true)),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const RetrailApp(),
      ),
    );
    // App errors (a preview file read while written, a map tile) are logged,
    // not test failures: the shot and its text check judge the screen.
    final onError = FlutterError.onError;
    FlutterError.onError = (details) {
      // ignore: avoid_print
      print('RETRAIL_APP_ERROR ${details.exceptionAsString()}');
    };
    return _App(tester, container, db, source, onError);
  }

  Future<void> close() async {
    // Unmount first: screens release their providers in dispose().
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    container.dispose();
    FlutterError.onError = _onError;
    try {
      await db.close();
    } catch (_) {}
  }
}

/// Pumps frames for [d] of real time.
Future<void> _wait(WidgetTester tester, Duration d) async {
  final end = DateTime.now().add(d);
  do {
    await tester.pump(const Duration(milliseconds: 100));
  } while (DateTime.now().isBefore(end));
}

/// Lets the screen settle, then asks the script for a screenshot.
///
/// With [freeze], no frame is drawn until the host has taken the shot (frame
/// policy onlyPumps, and no pump while waiting): the screen keeps the last
/// frame however long the host takes, while timers keep running behind it.
/// For motives that change on their own, such as the countdown digit.
Future<void> _shot(
  WidgetTester tester,
  String name, {
  Duration settle = const Duration(seconds: 2),
  bool freeze = false,
}) async {
  if (!_wanted(name)) return;
  await _wait(tester, settle);
  final binding = IntegrationTestWidgetsFlutterBinding.instance;
  if (freeze) {
    await tester.pump();
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
  }
  try {
    await _handshake(
      'RETRAIL_SHOT $name',
      name,
      // Generous: the simulator host is slow while the map renders.
      const Duration(minutes: 3),
      // A pump draws a frame, so a frozen shot waits without pumping.
      tester: freeze ? null : tester,
    );
  } finally {
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  }
}

/// Prints [marker] and waits (pumping frames) until the script wrote the ack
/// file Documents/shot_ack/[ack]. Gives up after [timeout]; the script then
/// misses that shot and fails.
Future<void> _handshake(
  String marker,
  String ack,
  Duration timeout, {
  WidgetTester? tester,
}) async {
  final docs = await getApplicationDocumentsDirectory();
  final file = File(p.join(docs.path, 'shot_ack', ack));
  // ignore: avoid_print — the script reads the marker from stdout.
  print(marker);
  final end = DateTime.now().add(timeout);
  while (!file.existsSync()) {
    if (DateTime.now().isAfter(end)) {
      // ignore: avoid_print
      print('RETRAIL_NO_ACK $ack');
      return;
    }
    if (tester != null) {
      await tester.pump(const Duration(milliseconds: 200));
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }
}

/// Replays the newest demo ride as live GPS: one fix per second (its recorded
/// pace), optionally fast-forwarding the first part of the route.
class _ReplaySource implements LocationSource {
  List<Trackpoint> _points = const [];
  double _fastUntil = 0;

  Future<void> useNewestRide(
    ProviderContainer container, {
    double fastUntil = 0,
  }) async {
    final rides = await container
        .read(rideRepositoryProvider)
        .getAllRides()
        .first;
    final newest = rides.reduce(
      (a, b) => (a.startTime ?? 0) >= (b.startTime ?? 0) ? a : b,
    );
    _points = await container
        .read(trackpointRepositoryProvider)
        .getForRide(newest.rideId)
        .first;
    _fastUntil = fastUntil;
  }

  LocationFix _fix(Trackpoint t) => LocationFix(
    latitude: t.latitude,
    longitude: t.longitude,
    accuracy: 4,
    hasSpeed: t.speed != null,
    speed: t.speed ?? 0,
    elapsedRealtimeNanos: DateTime.now().microsecondsSinceEpoch * 1000,
  );

  @override
  Stream<LocationFix> get fixes async* {
    final fast = (_points.length * _fastUntil).round();
    for (var i = 0; i < _points.length; i++) {
      yield _fix(_points[i]);
      await Future<void>.delayed(
        i < fast
            ? const Duration(milliseconds: 40)
            : const Duration(seconds: 1),
      );
    }
  }

  @override
  Future<LocationFix?> lastKnown() async =>
      _points.isEmpty ? null : _fix(_points.first);

  @override
  Stream<bool> get serviceEnabled => const Stream.empty();
}

class _Granted implements LocationPermissionService {
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.always;
  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.always;
  @override
  Future<bool> isPreciseLocation() async => true;
  @override
  Future<void> requestPreciseLocation() async {}
  @override
  Future<void> ensureBackgroundPermission() async {}
  @override
  Future<void> openLocationSettings() async {}
  @override
  Future<void> openAppSettings() async {}
}

class _NoService implements RideForegroundService {
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

class _Silent implements CountdownAnnouncer {
  @override
  Future<void> prepare(Locale locale) async {}
  @override
  Future<void> count(int second) async {}
  @override
  Future<void> go() async {}
  @override
  Future<void> stop() async {}
}
