import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/app.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/home_test_helpers.dart';

void main() {
  testWidgets('walks name → photo → activity → main and persists choices',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = PreferencesRepository(await SharedPreferences.getInstance());
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      preferencesRepositoryProvider.overrideWithValue(prefs),
      ...homeStreamStubs(),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const RetrailApp()),
    );
    await tester.pumpAndSettle();

    // Step 1: name
    expect(find.text('Welcome to Retrail'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Vali');
    await tester.pump();
    expect(find.text('4/30'), findsOneWidget);
    await tester.tap(find.text("Let's go"));
    await tester.pumpAndSettle();

    // Step 2: profile photo (blank)
    expect(find.text('Looking good, Vali!'), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Step 3: activity
    expect(find.text('How do you roll?'), findsOneWidget);
    await tester.tap(find.text('Scooter'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Lands on the main shell.
    expect(find.text('Home'), findsWidgets);

    // Choices persisted.
    expect(await prefs.userName.first, 'Vali');
    expect(await prefs.lastActivityType.first, 'SCOOTER');
    expect(await prefs.onboardingDone.first, true);
  });

  testWidgets(
      'system back steps back through onboarding instead of closing the app '
      '(issue #32)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = PreferencesRepository(await SharedPreferences.getInstance());
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      preferencesRepositoryProvider.overrideWithValue(prefs),
      ...homeStreamStubs(),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const RetrailApp()),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Vali');
    await tester.tap(find.text("Let's go"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('How do you roll?'), findsOneWidget);

    // Back from the activity step → photo step.
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Looking good, Vali!'), findsOneWidget);

    // Back from the photo step → name step (name still filled in).
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Retrail'), findsOneWidget);
    expect(find.text('Vali'), findsOneWidget);
  });
}
