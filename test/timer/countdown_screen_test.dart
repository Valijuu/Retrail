import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:retrail/core/theme/app_colors.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:retrail/features/timer/countdown_screen.dart';
import 'package:retrail/l10n/app_localizations.dart';
import 'package:retrail/tracking/ride_recording_controller.dart';
import 'package:retrail/tracking/tracking_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockRecording extends Mock implements RideRecordingController {}

late _MockRecording _recording;

Future<Widget> _app(WidgetTester tester,
    {Map<String, Object> prefs = const {'last_activity_type': 'SCOOTER'},
    Brightness brightness = Brightness.light,
    bool beginProceeds = true}) async {
  _recording = _MockRecording();
  when(() => _recording.arm()).thenAnswer((_) async {});
  when(() => _recording.disarm()).thenAnswer((_) async {});
  when(() => _recording.beginArmedRide())
      .thenAnswer((_) async => beginProceeds);
  when(() => _recording.armCancelled).thenReturn(false);
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues(prefs);
  final repo = PreferencesRepository(await SharedPreferences.getInstance());
  final router = GoRouter(initialLocation: '/timer', routes: [
    GoRoute(
        path: '/',
        builder: (c, s) => const Scaffold(body: Center(child: Text('home')))),
    GoRoute(path: '/timer', builder: (c, s) => const CountdownScreen()),
    GoRoute(
        path: '/ride',
        builder: (c, s) => const Scaffold(body: Center(child: Text('ride')))),
  ]);
  return ProviderScope(
    overrides: [
      preferencesRepositoryProvider.overrideWithValue(repo),
      rideRecordingControllerProvider.overrideWithValue(_recording),
    ],
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

  // Issue #77: arm while the app is surely in front; begin the ride at 0
  // before navigating, so it never waits for the ride screen to be built.
  testWidgets('opening the countdown arms the recording', (tester) async {
    await tester.pumpWidget(await _app(tester));
    await tester.pump();
    verify(() => _recording.arm()).called(1);
    verifyNever(() => _recording.beginArmedRide());
  });

  testWidgets('reaching 0 begins the armed ride before navigating',
      (tester) async {
    await tester.pumpWidget(await _app(tester));
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    verify(() => _recording.beginArmedRide()).called(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('ride'), findsOneWidget);
    // Leaving for the ride screen must not tear the armed recording down.
    verifyNever(() => _recording.disarm());
  });

  testWidgets('a start cancelled meanwhile (notification Stop) goes home',
      (tester) async {
    await tester.pumpWidget(await _app(tester, beginProceeds: false));
    await tester.pump();
    await tester.tap(find.text('Start now'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('home'), findsOneWidget);
    expect(find.text('ride'), findsNothing);
  });

  testWidgets('back right after Start now, before the ride began, disarms',
      (tester) async {
    await tester.pumpWidget(await _app(tester));
    final begin = Completer<bool>();
    when(() => _recording.beginArmedRide()).thenAnswer((_) => begin.future);
    await tester.pump();
    await tester.tap(find.text('Start now'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    verify(() => _recording.disarm()).called(1);
    begin.complete(false);
  });

  testWidgets('a Stop from the notification during the countdown leaves at '
      'once', (tester) async {
    await tester.pumpWidget(await _app(tester));
    await tester.pump();
    when(() => _recording.armCancelled).thenReturn(true);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('home'), findsOneWidget);
    verifyNever(() => _recording.beginArmedRide());
  });

  testWidgets('leaving the countdown without starting disarms', (tester) async {
    await tester.pumpWidget(await _app(tester));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    verify(() => _recording.disarm()).called(1);
    verifyNever(() => _recording.beginArmedRide());
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
