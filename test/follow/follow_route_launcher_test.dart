import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:retrail/core/connectivity/connectivity_providers.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/features/follow/follow_route_launcher.dart';
import 'package:retrail/features/follow/route_follow_providers.dart';
import 'package:retrail/l10n/app_localizations.dart';
import 'package:retrail/tracking/location_permission.dart';
import 'package:retrail/tracking/tracking_providers.dart';

import '../home/home_test_helpers.dart';

const _ref = [(lat: 48.0, lng: 11.0), (lat: 48.001, lng: 11.0)];

void main() {
  late FakeRecordingController recording;
  late ProviderContainer container;

  Future<void> pumpLauncher(
    WidgetTester tester, {
    bool tracking = false,
    List<({double lat, double lng})> ref = _ref,
  }) async {
    final env = await buildHomeEnv(initialPrefs: {'onboarding_done': true});
    addTearDown(env.db.close);
    recording = makeFakeRecording(env.db);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (c, s) => Consumer(
            builder: (context, ref2, _) => TextButton(
              onPressed: () => launchFollowRoute(
                context,
                ref2,
                reference: ref,
                rideTitle: 'Rhein',
              ),
              child: const Text('go'),
            ),
          ),
        ),
        GoRoute(path: '/timer', builder: (c, s) => const Text('TIMER')),
        GoRoute(path: '/ride', builder: (c, s) => const Text('RIDE')),
        GoRoute(path: '/follow', builder: (c, s) => const Text('FOLLOW')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(env.db),
          preferencesRepositoryProvider.overrideWithValue(env.prefs),
          isOnlineProvider.overrideWith((ref) => Stream.value(true)),
          isTrackingProvider.overrideWithValue(tracking),
          ...activeRideTestOverrides(env.db, recording: recording),
        ],
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
      ),
    );
    container = ProviderScope.containerOf(tester.element(find.text('go')));
  }

  testWidgets('asks whether to record', (tester) async {
    await pumpLauncher(tester);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Record this ride?'), findsOneWidget);
    expect(find.text('Record'), findsOneWidget);
    expect(find.text('Just follow'), findsOneWidget);
  });

  testWidgets('Record sets a recording reference and opens the countdown', (
    tester,
  ) async {
    await pumpLauncher(tester);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record'));
    await tester.pumpAndSettle();
    expect(find.text('TIMER'), findsOneWidget);
    final s = container.read(routeFollowProvider)!;
    expect(s.recording, isTrue);
    expect(s.rideTitle, 'Rhein');
  });

  testWidgets('Just follow sets a follow-only reference and opens /follow', (
    tester,
  ) async {
    await pumpLauncher(tester);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Just follow'));
    await tester.pumpAndSettle();
    expect(find.text('FOLLOW'), findsOneWidget);
    expect(container.read(routeFollowProvider)!.recording, isFalse);
    expect(recording.calls, contains('prepare'));
  });

  testWidgets('dismissing the dialog does nothing', (tester) async {
    await pumpLauncher(tester);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5)); // barrier
    await tester.pumpAndSettle();
    expect(find.text('go'), findsOneWidget);
    expect(container.read(routeFollowProvider), isNull);
  });

  testWidgets('blocked permission: gate dialog, no navigation, no reference', (
    tester,
  ) async {
    await pumpLauncher(tester);
    recording.prepareResult = LocationStartAction.showRationale;
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Just follow'));
    await tester.pumpAndSettle();
    expect(find.text('Location needed'), findsOneWidget);
    expect(find.text('FOLLOW'), findsNothing);
    expect(container.read(routeFollowProvider), isNull);
  });

  testWidgets('blocked permission on Record leaves no reference', (
    tester,
  ) async {
    await pumpLauncher(tester);
    recording.prepareResult = LocationStartAction.showRationale;
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record'));
    await tester.pumpAndSettle();
    expect(find.text('Location needed'), findsOneWidget);
    expect(find.text('TIMER'), findsNothing);
    expect(container.read(routeFollowProvider), isNull);
  });

  testWidgets('while a ride is recording: straight to it, no reference', (
    tester,
  ) async {
    await pumpLauncher(tester, tracking: true);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Record this ride?'), findsNothing);
    expect(find.text('RIDE'), findsOneWidget);
    expect(container.read(routeFollowProvider), isNull);
  });

  testWidgets('a reference with fewer than 2 points is ignored', (
    tester,
  ) async {
    await pumpLauncher(tester, ref: const [(lat: 48.0, lng: 11.0)]);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Record this ride?'), findsNothing);
    expect(find.text('go'), findsOneWidget);
    expect(container.read(routeFollowProvider), isNull);
  });
}
