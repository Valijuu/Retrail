import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:retrail/core/theme/app_colors.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:retrail/features/timer/countdown_screen.dart';
import 'package:retrail/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _app(WidgetTester tester,
    {Map<String, Object> prefs = const {'last_activity_type': 'SCOOTER'},
    Brightness brightness = Brightness.light}) async {
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
      theme: buildTheme(brightness),
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

  testWidgets('the countdown block is horizontally centred', (tester) async {
    await tester.pumpWidget(await _app(tester));
    await tester.pump();
    // 400-wide screen → centre at x≈200. The bug pinned the block to the left
    // (Stack topStart + a shrink-wrapped column), landing the digit near x≈114.
    expect(tester.getCenter(find.text('5')).dx, moreOrLessEquals(200, epsilon: 1));
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

  /// The ring's current sweep (0 = empty, 1 = full), read off its painter.
  double ringProgress(WidgetTester tester) {
    final paint = tester.widgetList<CustomPaint>(find.byType(CustomPaint))
        .firstWhere((p) => p.painter.runtimeType.toString() == '_RingPainter');
    return (paint.painter as dynamic).progress as double;
  }

  testWidgets('the ring drains in step with the digit and is empty at 0',
      (tester) async {
    await tester.pumpWidget(await _app(tester));
    await tester.pump();
    expect(ringProgress(tester), moreOrLessEquals(1.0, epsilon: 0.01));

    // Halfway through "5": the ring is on its way from 5/5 to 4/5.
    await tester.pump(const Duration(milliseconds: 500));
    expect(ringProgress(tester), moreOrLessEquals(0.9, epsilon: 0.02));

    // Halfway through "1" (4.5 s in): heading from 1/5 to empty. Pumped in
    // frame-sized steps so each tick's glide starts on time, like on device.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('1'), findsOneWidget);
    expect(ringProgress(tester), moreOrLessEquals(0.1, epsilon: 0.02));
  });

  for (final brightness in Brightness.values) {
    testWidgets('$brightness app theme: Start now label stays onPrimary '
        '(the countdown\'s fixed palette)', (tester) async {
      await tester.pumpWidget(await _app(tester, brightness: brightness));
      await tester.pump();
      final label = tester.renderObject<RenderParagraph>(find.text('Start now'));
      expect(label.text.style?.color, AppColors.light.onPrimary);
    });
  }
}
