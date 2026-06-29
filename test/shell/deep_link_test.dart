import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/app.dart';
import 'package:retrail/core/connectivity/connectivity_providers.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:retrail/features/shell/startup_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/home_test_helpers.dart';

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

void main() {
  testWidgets('a pending ride deep-link routes to /ride and clears the flag',
      (tester) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final container = await _pumpApp(tester, db);
    // Onboarding done → main shell.
    expect(find.text('Home'), findsOneWidget);

    container.read(pendingRideDeepLinkProvider.notifier).state = true;
    await tester.pump(); // redirect
    await tester.pump(const Duration(milliseconds: 200)); // fade transition
    await tester.pump(); // active-ride post-frame: clear the flag

    expect(find.text('Retrail ride'), findsOneWidget);
    expect(container.read(pendingRideDeepLinkProvider), isFalse);
  });

  testWidgets(
      'leaving the ride clears a deep-link latch set while already on it '
      '(no bounce-back)', (tester) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final container = await _pumpApp(tester, db);
    expect(find.text('Home'), findsOneWidget);

    // Open the ride via deep-link; the screen clears the latch on mount.
    container.read(pendingRideDeepLinkProvider.notifier).state = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(find.text('Retrail ride'), findsOneWidget);

    // Tapping the ride notification body again, while we're *already* on the
    // ride screen, re-sets the latch — and initState's clear never re-runs.
    container.read(pendingRideDeepLinkProvider.notifier).state = true;
    await tester.pump();
    expect(find.text('Retrail ride'), findsOneWidget); // redirect no-ops here

    // Leaving the ride (back, not tracking → straight home) must not be bounced
    // back to /ride by the stale latch.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Retrail ride'), findsNothing);
    expect(container.read(pendingRideDeepLinkProvider), isFalse);
  });
}
