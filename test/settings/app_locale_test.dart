import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/app.dart';
import 'package:retrail/core/connectivity/connectivity_providers.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:retrail/features/settings/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/home_test_helpers.dart';

Future<void> _pumpApp(WidgetTester tester, Locale locale) async {
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
    localeProvider.overrideWithValue(locale),
    ...activeRideTestOverrides(db),
    ...homeStreamStubs(),
  ]);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const RetrailApp()),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('locale de renders German bottom-nav labels', (tester) async {
    await _pumpApp(tester, const Locale('de'));
    expect(find.text('Verlauf'), findsOneWidget); // History → Verlauf
    expect(find.text('Einstellungen'), findsOneWidget); // Settings
  });

  testWidgets('locale en renders English bottom-nav labels', (tester) async {
    await _pumpApp(tester, const Locale('en'));
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
