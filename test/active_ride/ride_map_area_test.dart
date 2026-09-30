import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/features/active_ride/widgets/ride_chrome.dart';
import 'package:retrail/l10n/app_localizations.dart';
import 'package:retrail/tracking/ride_tracking_state.dart';

import '../support/live_map_stub.dart';

void main() {
  useStubLiveMap();

  Future<void> pumpArea(WidgetTester tester,
      {VoidCallback? onReverse, bool masked = false}) async {
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
          isFollowing: true,
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

  testWidgets('no onReverse: no reverse button', (tester) async {
    await pumpArea(tester);
    expect(find.byIcon(Icons.swap_vert), findsNothing);
  });

  testWidgets('masked (leaving): no reverse button', (tester) async {
    await pumpArea(tester, onReverse: () {}, masked: true);
    expect(find.byIcon(Icons.swap_vert), findsNothing);
  });
}
