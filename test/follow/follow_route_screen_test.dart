import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:retrail/core/connectivity/connectivity_providers.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/domain/follow_direction.dart';
import 'package:retrail/domain/route_progress.dart';
import 'package:retrail/features/active_ride/widgets/ride_chrome.dart';
import 'package:retrail/features/follow/follow_route_screen.dart';
import 'package:retrail/features/follow/route_follow_providers.dart';
import 'package:retrail/features/follow/widgets/follow_chrome.dart';
import 'package:retrail/features/home/navigation_launcher.dart';
import 'package:retrail/l10n/app_localizations.dart';

import '../support/live_map_stub.dart';

class FakeNavigationLauncher implements NavigationLauncher {
  final launches = <(double, double, String)>[];
  @override
  Future<List<NavigationApp>> availableApps() async =>
      const [NavigationApp.system];
  @override
  Future<void> launch(
          NavigationApp app, double lat, double lng, String label) async =>
      launches.add((lat, lng, label));
}

class _FakeFollow extends RouteFollowNotifier {
  _FakeFollow(this.initial);
  final RouteFollowState? initial;
  final calls = <String>[];
  @override
  RouteFollowState? build() => initial;
  @override
  Future<void> resumeFeed() async => calls.add('resume');
  @override
  void pauseFeed() => calls.add('pause');
  RouteTrack? pausedFor;
  @override
  void pauseFeedFor(RouteTrack track) {
    calls.add('pauseFor');
    pausedFor = track;
  }
  @override
  void stop() {
    calls.add('stop');
    state = null;
  }
  @override
  void flipDirection() => calls.add('flip');
}

RouteFollowState _state({String? title = 'Rhein', RouteProgress? progress,
        bool locationOn = true,
        FollowDirection direction = FollowDirection.forward,
        RouteTrack? orientedTrack,
        List<List<({double lat, double lng})>> ridden = const []}) =>
    RouteFollowState(
      track: RouteTrack(const [(lat: 48.0, lng: 11.0), (lat: 48.01, lng: 11.0)]),
      recording: false,
      rideTitle: title,
      progress: progress,
      locationServiceEnabled: locationOn,
      direction: direction,
      orientedTrack: orientedTrack,
      ridden: ridden,
    );

RouteProgress _p({bool joined = true, bool off = false, double offset = 2,
        double remaining = 812, bool finished = false}) =>
    RouteProgress(alongM: 300, remainingM: remaining, offsetM: offset,
        isOffRoute: off, isFinished: finished, hasJoined: joined);

void main() {
  useStubLiveMap();
  late _FakeFollow follow;
  late FakeNavigationLauncher launcher;

  Future<void> pump(WidgetTester tester, RouteFollowState? s,
      {bool online = true, Size size = const Size(400, 900),
      Locale? locale}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    follow = _FakeFollow(s);
    launcher = FakeNavigationLauncher();
    final router = GoRouter(initialLocation: '/follow', routes: [
      GoRoute(path: '/', builder: (c, s) => const Text('HOME')),
      GoRoute(path: '/follow', builder: (c, s) => const FollowRouteScreen()),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        routeFollowProvider.overrideWith(() => follow),
        isOnlineProvider.overrideWith((ref) => Stream.value(online)),
        navigationLauncherProvider.overrideWithValue(launcher),
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
        locale: locale,
        routerConfig: router,
      ),
    ));
    await tester.pump();
  }

  testWidgets('title, ride title and remaining distance', (tester) async {
    await pump(tester, _state(progress: _p()));
    expect(find.text('Follow route'), findsOneWidget);
    expect(find.text('Rhein'), findsOneWidget);
    expect(find.text('0.81 km to go'), findsOneWidget);
    expect(follow.calls, contains('resume'));
  });

  testWidgets('before the first fix: the remaining line shows the route length',
      (tester) async {
    await pump(tester, _state());
    expect(find.text('1.11 km to go'), findsOneWidget);
  });

  testWidgets('no ride title line when the ride has none', (tester) async {
    await pump(tester, _state(title: null, progress: _p()));
    expect(find.text('Rhein'), findsNothing);
  });

  testWidgets('End asks first; Cancel keeps following', (tester) async {
    await pump(tester, _state(progress: _p()));
    await tester.tap(find.text('End'));
    await tester.pumpAndSettle();
    expect(find.text('End following?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(follow.calls, isNot(contains('stop')));
    expect(find.text('HOME'), findsNothing);
  });

  testWidgets('End confirmed stops and goes home', (tester) async {
    await pump(tester, _state(progress: _p()));
    await tester.tap(find.text('End'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'End').last);
    await tester.pumpAndSettle();
    expect(follow.calls, contains('stop'));
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('system back opens the same confirmation', (tester) async {
    await pump(tester, _state(progress: _p()));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('End following?'), findsOneWidget);
  });

  testWidgets('not on the route yet: banner + Navigate to start',
      (tester) async {
    await pump(tester, _state(progress: _p(joined: false, off: true, offset: 250)));
    expect(find.text('250 m to the route'), findsOneWidget);
    await tester.tap(find.text('Navigate to start'));
    await tester.pump();
    expect(launcher.launches.first.$1, 48.0);
    expect(launcher.launches.first.$3, 'Rhein');
  });

  testWidgets('a blank ride title navigates with the "Follow route" label',
      (tester) async {
    await pump(tester,
        _state(title: '   ', progress: _p(joined: false, off: true, offset: 250)));
    await tester.tap(find.text('Navigate to start'));
    await tester.pump();
    expect(launcher.launches.first.$3, 'Follow route');
  });

  testWidgets('on the route: no Navigate to start', (tester) async {
    await pump(tester, _state(progress: _p()));
    expect(find.text('Navigate to start'), findsNothing);
  });

  testWidgets('finish reached hint', (tester) async {
    await pump(tester, _state(progress: _p(finished: true, remaining: 3)));
    expect(find.text('Finish reached'), findsOneWidget);
  });

  testWidgets('app backgrounded pauses the feed, foreground resumes it',
      (tester) async {
    await pump(tester, _state(progress: _p()));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(follow.calls.last, 'pause');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(follow.calls.last, 'resume');
  });

  testWidgets('an inactive app alone does not pause the feed', (tester) async {
    await pump(tester, _state(progress: _p()));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(follow.calls, isNot(contains('pause')));
  });

  testWidgets('leaving the screen pauses only its own session\'s feed (#50)',
      (tester) async {
    final session = _state(progress: _p());
    await pump(tester, session);
    await tester.pumpWidget(const SizedBox());
    expect(follow.calls, contains('pauseFor'));
    expect(follow.pausedFor, same(session.track));
  });

  testWidgets('offline shows the map offline banner', (tester) async {
    await pump(tester, _state(progress: _p()), online: false);
    await tester.pump();
    expect(find.text('Offline — map tiles may not be available'), findsOneWidget);
  });

  testWidgets('location off shows the follow location banner', (tester) async {
    await pump(tester, _state(progress: _p(), locationOn: false));
    expect(
        find.text(
            "Location is off — your position can't be shown. Tap to turn it on."),
        findsOneWidget);
  });

  testWidgets('without a reference it goes home', (tester) async {
    await pump(tester, null);
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    // No session was opened, so disposing must not pause anyone's feed.
    expect(follow.calls, isNot(contains('pauseFor')));
  });

  testWidgets('leaving keeps the follow chrome until the route changes',
      (tester) async {
    await pump(tester, _state(progress: _p()));
    await tester.tap(find.text('End'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'End').last);
    await tester.pump();
    expect(find.text('Follow route'), findsOneWidget);
  });

  testWidgets('reversed: the remaining text says so', (tester) async {
    await pump(tester,
        _state(progress: _p(), direction: FollowDirection.reverse));
    expect(find.text('0.81 km to go · reversed'), findsOneWidget);
  });

  testWidgets('undecided: the route length, never the finish', (tester) async {
    await pump(tester,
        _state(progress: _p(finished: true, remaining: 3),
            direction: FollowDirection.undecided));
    expect(find.text('1.11 km to go'), findsOneWidget);
    expect(find.text('Finish reached'), findsNothing);
  });

  testWidgets('joined: the flip button shows and flips the direction',
      (tester) async {
    await pump(tester, _state(progress: _p()));
    await tester.tap(find.byTooltip('Reverse direction'));
    expect(follow.calls, contains('flip'));
  });

  testWidgets('not joined: no flip button', (tester) async {
    await pump(tester,
        _state(progress: _p(joined: false, off: true, offset: 250)));
    expect(find.byTooltip('Reverse direction'), findsNothing);
  });

  testWidgets('the map draws the oriented route and its ridden parts',
      (tester) async {
    final reversed = RouteTrack(
        const [(lat: 48.01, lng: 11.0), (lat: 48.0, lng: 11.0)]);
    const ridden = [
      [(lat: 48.01, lng: 11.0), (lat: 48.005, lng: 11.0)],
    ];
    await pump(tester,
        _state(progress: _p(), orientedTrack: reversed, ridden: ridden));
    final map = tester.widget<RideMapArea>(find.byType(RideMapArea));
    expect(map.reference, same(reversed));
    expect(map.referenceDone, ridden);
  });

  testWidgets('the remaining text shares one bottom bar with End',
      (tester) async {
    await pump(tester, _state(progress: _p()));
    expect(find.byType(FollowRemainingLine), findsNothing);
    final label = tester.getRect(find.text('0.81 km to go'));
    final end = tester.getRect(find.widgetWithText(FilledButton, 'End'));
    expect(label.center.dy, closeTo(end.center.dy, 0.5));
    expect(label.right, lessThanOrEqualTo(end.left));
  });

  testWidgets('before joining: Navigate to start spans the bar below',
      (tester) async {
    await pump(tester,
        _state(progress: _p(joined: false, off: true, offset: 250)));
    final label = tester.getRect(find.text('0.81 km to go'));
    final end = tester.getRect(find.widgetWithText(FilledButton, 'End'));
    final nav = tester.getRect(find.ancestor(
        of: find.text('Navigate to start'), matching: find.byType(FilledButton)));
    expect(nav.top, greaterThanOrEqualTo(end.bottom));
    expect(nav.left, label.left);
    expect(nav.right, end.right);
  });

  for (final (locale, texts) in [
    (const Locale('en'), ['0.81 km to go · reversed', 'End', 'Navigate to start']),
    (const Locale('de'), ['noch 0,81 km · rückwärts', 'Beenden', 'Zum Start navigieren']),
  ]) {
    testWidgets('375 px, $locale: the bottom bar fits without truncation',
        (tester) async {
      await pump(tester,
          _state(progress: _p(joined: false, off: true, offset: 250),
              direction: FollowDirection.reverse),
          size: const Size(375, 667), locale: locale);
      expect(tester.takeException(), isNull);
      for (final t in texts) {
        final paragraph =
            tester.renderObject<RenderParagraph>(find.text(t));
        expect(paragraph.didExceedMaxLines, isFalse, reason: t);
      }
    });
  }
}
