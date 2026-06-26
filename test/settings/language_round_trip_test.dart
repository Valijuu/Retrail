import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/app.dart';
import 'package:retrail/core/connectivity/connectivity_providers.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/home_test_helpers.dart';

/// Exercises the *real* language-switch chain end to end — no `localeProvider`
/// override — so the wiring `setLanguage → prefs.language → appLanguageProvider
/// → localeProvider → MaterialApp.locale` is actually proven, not stubbed.
void main() {
  testWidgets('selecting Deutsch in Settings re-localizes the whole app',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({'onboarding_done': true});
    final prefs = PreferencesRepository(await SharedPreferences.getInstance());
    final db = AppDatabase.memory();
    addTearDown(db.close);

    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      preferencesRepositoryProvider.overrideWithValue(prefs),
      isOnlineProvider.overrideWith((ref) => Stream.value(true)),
      ...activeRideTestOverrides(db),
      ...homeStreamStubs(),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const RetrailApp()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Starts in English (system locale → en in the test environment).
    expect(find.text('Settings'), findsOneWidget); // bottom-nav label

    // Navigate to the Settings tab.
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The language option is shown in English before switching.
    expect(find.text('Deutsch'), findsOneWidget);

    // Switch the app language to German.
    await tester.tap(find.text('Deutsch'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The whole app re-localizes: bottom nav now reads German.
    expect(find.text('Verlauf'), findsOneWidget); // History → Verlauf
    expect(find.text('Einstellungen'), findsWidgets); // nav + screen header
    expect(find.text('History'), findsNothing);
  });
}
