import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/app.dart';
import 'package:retrail/core/connectivity/connectivity_providers.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/domain/activity_type.dart';
import 'package:retrail/domain/stats_aggregation.dart';
import 'package:retrail/features/home/recent_ride_ui.dart';
import 'package:retrail/tracking/location_permission.dart';
import 'package:retrail/tracking/tracking_providers.dart';

import '../support/live_map_stub.dart';
import 'home_test_helpers.dart';

/// Bounded settle — HomeScreen's stream providers stay subscribed, so
/// `pumpAndSettle` never returns; pump a fixed window instead.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  useStubLiveMap();

  Future<FakeRecordingController> pumpHome(
    WidgetTester tester, {
    bool tracking = false,
    bool online = true,
    List<RecentRideUi> recent = const [],
    List<RecentRideUi> favorites = const [],
    WeeklyStats weekly = const WeeklyStats.zero(),
    Map<String, Object> prefs = const {},
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final env = await buildHomeEnv(
        initialPrefs: {'onboarding_done': true, ...prefs});
    addTearDown(env.db.close);
    // Build the recording controller from env.db so only one AppDatabase
    // instance exists per test (avoids Drift's multiple-database warning).
    final recording = makeFakeRecording(env.db);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(env.db),
        preferencesRepositoryProvider.overrideWithValue(env.prefs),
        // A stream, like the real ConnectivityObserver — Home must keep it
        // subscribed so the Start tap sees the real value (issue #31: a bare
        // read saw a paused provider and always assumed online).
        isOnlineProvider.overrideWith((ref) => Stream.value(online)),
        if (tracking) isTrackingProvider.overrideWithValue(true),
        ...activeRideTestOverrides(env.db, recording: recording),
        ...homeStreamStubs(
            recent: recent, favorites: favorites, weekly: weekly),
      ],
      child: const RetrailApp(),
    ));
    await _settle(tester);
    return recording;
  }

  testWidgets('renders sections with empty placeholders', (tester) async {
    await pumpHome(tester);
    expect(find.text('Recent rides'), findsOneWidget);
    expect(find.text('No rides yet — time to roll.'), findsOneWidget);
    expect(find.text('Recent favorites'), findsOneWidget);
    expect(find.text('No favorites yet.'), findsOneWidget);
  });

  testWidgets('renders ride cards and hero stats from populated data',
      (tester) async {
    await pumpHome(
      tester,
      recent: const [
        RecentRideUi(
          rideId: 1,
          title: 'Morning roll',
          dateTime: 'Today, 08:00',
          distanceKm: 4.2,
          hasRoute: true,
        ),
      ],
      weekly: const WeeklyStats(
        totalKm: 12.5,
        rideCount: 3,
        avgSpeedKmh: 0,
        totalDurationSeconds: 0,
      ),
    );
    expect(find.text('Morning roll'), findsOneWidget);
    expect(find.text('4.2 km'), findsOneWidget); // ride-card distance
    expect(find.text('12.5 km'), findsOneWidget); // weekly hero distance
  });

  testWidgets('Start tracking routes to the countdown timer', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('Start tracking'));
    await _settle(tester);
    expect(find.text('GET READY'), findsOneWidget);
  });

  testWidgets(
      'first Start after launch keeps the saved activity instead of '
      'overwriting it with the default (issue #27)', (tester) async {
    await pumpHome(tester, prefs: {'last_activity_type': 'OTHER'});
    await tester.tap(find.text('Start tracking'));
    await _settle(tester);

    expect(find.text('Other'), findsOneWidget); // countdown activity chip
    final container =
        ProviderScope.containerOf(tester.element(find.text('GET READY')));
    expect(container.read(rideTrackerProvider).state.activityType,
        ActivityType.other);
    final saved = await tester.runAsync(() => container
        .read(preferencesRepositoryProvider)
        .lastActivityType
        .first);
    expect(saved, 'OTHER');
  });

  testWidgets('Start tracking requests permission before the countdown',
      (tester) async {
    final recording = await pumpHome(tester);
    await tester.tap(find.text('Start tracking'));
    await _settle(tester);
    // The gate ran at the button press (not after the countdown screen).
    expect(recording.calls, contains('prepare'));
    expect(find.text('GET READY'), findsOneWidget);
  });

  testWidgets('blocked permission shows the rationale and does not navigate',
      (tester) async {
    final recording = await pumpHome(tester);
    recording.prepareResult = LocationStartAction.showRationale;
    await tester.tap(find.text('Start tracking'));
    await _settle(tester);
    expect(recording.calls, contains('prepare'));
    expect(find.text('Location needed'), findsOneWidget); // rationale dialog
    expect(find.text('GET READY'), findsNothing); // never reached the countdown
  });

  testWidgets('offline Start still gates permission before the countdown',
      (tester) async {
    // Offline funnels through the same gate (recording needs location even with
    // no tiles); the offline confirm must not skip the prompt.
    final recording = await pumpHome(tester, online: false);
    await tester.tap(find.text('Start tracking'));
    await _settle(tester);
    expect(find.text("You're offline"), findsOneWidget); // offline confirm first
    await tester.tap(find.text('Start anyway'));
    await _settle(tester);
    expect(recording.calls, contains('prepare'));
    expect(find.text('GET READY'), findsOneWidget);
  });

  testWidgets(
      'offline confirm uses the stacked full-width buttons of the location '
      'dialog — primary on top, no shrink-to-fit', (tester) async {
    await pumpHome(tester, online: false);
    await tester.tap(find.text('Start tracking'));
    await _settle(tester);

    final primary = find.widgetWithText(FilledButton, 'Start anyway');
    final secondary = find.widgetWithText(TextButton, 'Skip');
    expect(tester.getSize(primary).width, tester.getSize(secondary).width);
    expect(tester.getTopLeft(primary).dy,
        lessThan(tester.getTopLeft(secondary).dy));
    expect(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(FittedBox)),
        findsNothing);
  });

  testWidgets('reopens the active ride when already tracking', (tester) async {
    await pumpHome(tester, tracking: true);
    await tester.tap(find.text('Start tracking'));
    await _settle(tester);
    expect(find.text('Retrail ride'), findsOneWidget);
  });
}
