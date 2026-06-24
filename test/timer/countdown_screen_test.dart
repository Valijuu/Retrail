import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:retrail/features/timer/countdown_screen.dart';
import 'package:retrail/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _app(WidgetTester tester,
    {Map<String, Object> prefs = const {'last_activity_type': 'SCOOTER'}}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues(prefs);
  final repo = PreferencesRepository(await SharedPreferences.getInstance());
  final router = GoRouter(initialLocation: '/timer', routes: [
    GoRoute(path: '/timer', builder: (c, s) => const CountdownScreen()),
    GoRoute(
        path: '/ride',
        builder: (c, s) => const Scaffold(body: Center(child: Text('ride')))),
  ]);
  return ProviderScope(
    overrides: [preferencesRepositoryProvider.overrideWithValue(repo)],
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
  );
}

void main() {
  testWidgets('renders label, activity chip, digit, tagline and GPS row',
      (tester) async {
    await tester.pumpWidget(await _app(tester));
    await tester.pump();
    expect(find.text('GET READY'), findsOneWidget);
    expect(find.text('Scooter'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.textContaining('Stay balanced'), findsOneWidget);
    expect(find.text('GPS signal'), findsOneWidget);
    expect(find.text('ready'), findsOneWidget);
  });

  testWidgets('+5 sec. extends the countdown', (tester) async {
    await tester.pumpWidget(await _app(tester));
    await tester.pump();
    await tester.tap(find.text('+5 sec.'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // settle switcher
    expect(find.text('10'), findsOneWidget);
  });

  testWidgets('Start now navigates to the ride screen', (tester) async {
    await tester.pumpWidget(await _app(tester));
    await tester.pump();
    await tester.tap(find.text('Start now'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('ride'), findsOneWidget);
  });

  testWidgets('reaching 0 auto-navigates to the ride screen', (tester) async {
    await tester.pumpWidget(await _app(tester));
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('ride'), findsOneWidget);
  });
}
