import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/app.dart';
import 'package:retrail/core/connectivity/connectivity_providers.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:retrail/features/active_ride/active_ride_screen.dart';
import 'package:retrail/features/timer/countdown_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/home_test_helpers.dart';
import '../support/live_map_stub.dart';

/// Regression guard for the "screen from the nav stack blinks during the
/// ride-exit" bug: home → timer → ride → stop → save → home, pumped
/// frame-by-frame, asserting the countdown page can never reappear once left
/// and the exit lands cleanly on home.
Future<ProviderContainer> _pumpApp(WidgetTester tester, AppDatabase db) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({'onboarding_done': true});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    appDatabaseProvider.overrideWithValue(db),
    preferencesRepositoryProvider
        .overrideWithValue(PreferencesRepository(prefs)),
    isOnlineProvider.overrideWith((ref) => Stream.value(true)),
    ...activeRideTestOverrides(db),
    ...homeStreamStubs(),
  ]);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const RetrailApp()),
  );
  // The home screen never settles, so pump fixed windows instead of settling.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return container;
}

/// Pumps [total] in ~16 ms frames, running [check] after every frame — catches
/// single-frame artifacts that a coarse pump would skip over.
Future<void> _pumpFrames(
    WidgetTester tester, Duration total, void Function() check) async {
  var elapsed = Duration.zero;
  const step = Duration(milliseconds: 16);
  while (elapsed < total) {
    await tester.pump(step);
    check();
    elapsed += step;
  }
}

void main() {
  useStubLiveMap();

  testWidgets(
      'the countdown page never reappears after leaving it — not during the '
      'ride entry, and not for a single frame of the save-exit back to home',
      (tester) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    await _pumpApp(tester, db);
    expect(find.text('Start tracking'), findsOneWidget);

    // Home → timer (permission gate is a headless fake → proceeds).
    await tester.tap(find.text('Start tracking'));
    await tester.pump(); // prepare() resolves
    await tester.pump(const Duration(milliseconds: 250)); // fade transition
    expect(find.byType(CountdownScreen), findsOneWidget);

    // Timer → ride, before the countdown reaches zero. The replaced timer
    // page legitimately stays mounted beneath the ride's 340 ms entry
    // cross-fade (Navigator keeps exiting pages until the incoming transition
    // completes) — but it must be GONE once the entry settles.
    await tester.tap(find.text('Start now'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // entry + margin
    expect(find.byType(ActiveRideScreen), findsOneWidget);
    expect(find.byType(CountdownScreen), findsNothing,
        reason: 'replaced timer page must be removed after the ride entry');
    void noCountdown() => expect(find.byType(CountdownScreen), findsNothing,
        reason: 'countdown page reappeared mid-transition');

    // Stop → confirm → summary → Save.
    await tester.tap(find.text('Stop ride'));
    await tester.pump();
    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(find.text('How was your ride?'), findsOneWidget);
    await tester.tap(find.text('Save'));

    // Exit transition (220 ms reverse + margin), frame-by-frame: neither the
    // countdown nor anything else from the old stack may blink through.
    await _pumpFrames(tester, const Duration(milliseconds: 600), noCountdown);

    expect(find.byType(ActiveRideScreen), findsNothing);
    expect(find.byType(CountdownScreen), findsNothing);
    expect(find.text('Start tracking'), findsOneWidget); // home, settled
  });
}
