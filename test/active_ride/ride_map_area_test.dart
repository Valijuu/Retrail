import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/features/active_ride/widgets/ride_chrome.dart';
import 'package:retrail/l10n/app_localizations.dart';
import 'package:retrail/map/map_attribution.dart';
import 'package:retrail/tracking/ride_tracking_state.dart';

import '../support/live_map_stub.dart';

void main() {
  useStubLiveMap();

  Future<void> pumpArea(WidgetTester tester,
      {VoidCallback? onReverse, bool masked = false, bool isFollowing = true})
      async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: RideMapArea(
          state: const RideTrackingState(),
          isFollowing: isFollowing,
          masked: masked,
          onGesture: () {},
          onRecenter: () {},
          onReverse: onReverse,
        ),
      ),
    ));
  }

  testWidgets('onReverse set: the reverse button shows and calls it',
      (tester) async {
    var taps = 0;
    await pumpArea(tester, onReverse: () => taps++);
    final button = find.byTooltip('Reverse direction');
    expect(button, findsOneWidget);
    expect(find.byIcon(Icons.swap_vert), findsOneWidget);
    await tester.tap(button);
    expect(taps, 1);
  });

  testWidgets('credits the map tiles, tappable', (tester) async {
    await pumpArea(tester, onReverse: () {}, isFollowing: false);
    final credit = tester.widget<MapAttribution>(find.byType(MapAttribution));
    expect(credit.onOpen, isNotNull);
  });

  testWidgets('masked (leaving): no map credit over the cover', (tester) async {
    await pumpArea(tester, masked: true);
    expect(find.byType(MapAttribution), findsNothing);
  });

  testWidgets('no onReverse: no reverse button', (tester) async {
    await pumpArea(tester);
    expect(find.byIcon(Icons.swap_vert), findsNothing);
  });

  testWidgets('masked (leaving): no reverse button', (tester) async {
    await pumpArea(tester, onReverse: () {}, masked: true);
    expect(find.byIcon(Icons.swap_vert), findsNothing);
  });

  testWidgets('not following + onReverse: recenter and reverse show together',
      (tester) async {
    await pumpArea(tester, onReverse: () {}, isFollowing: false);
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Re-center'), findsOneWidget);
    expect(find.byTooltip('Reverse direction'), findsOneWidget);
    // Two FABs with the default hero tag only clash in a route transition.
    tester.state<NavigatorState>(find.byType(Navigator)).push(
        MaterialPageRoute<void>(builder: (_) => const SizedBox()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
