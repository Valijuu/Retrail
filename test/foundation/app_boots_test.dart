import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/app.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('RetrailApp boots into the router shell', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        preferencesRepositoryProvider
            .overrideWithValue(PreferencesRepository(prefs)),
      ],
      child: const RetrailApp(),
    ));
    await tester.pumpAndSettle();

    // Boots without error and mounts the router. First run (onboarding not
    // done) lands on the init screen.
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Welcome to Retrail'), findsOneWidget);
  });
}
