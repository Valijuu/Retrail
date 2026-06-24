import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/app.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('walks name → photo → activity → main and persists choices',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = PreferencesRepository(await SharedPreferences.getInstance());
    final container = ProviderContainer(overrides: [
      preferencesRepositoryProvider.overrideWithValue(prefs),
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
}
