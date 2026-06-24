import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/features/home/recent_ride_ui.dart';
import 'package:retrail/features/home/ride_row_card.dart';
import 'package:retrail/l10n/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: buildTheme(Brightness.light),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('directions button invokes onNavigate for a routed ride',
      (tester) async {
    var navigated = false;
    await tester.pumpWidget(_wrap(RideRowCard(
      ride: const RecentRideUi(
        rideId: 1,
        title: 'Ride',
        dateTime: 'today',
        distanceKm: 1.2,
        hasRoute: true,
        startLat: 1,
        startLng: 2,
      ),
      onTap: () {},
      onNavigate: () => navigated = true,
    )));

    expect(find.text('1.2 km'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.directions));
    expect(navigated, isTrue);
  });

  testWidgets('no directions button when the ride has no route', (tester) async {
    await tester.pumpWidget(_wrap(RideRowCard(
      ride: const RecentRideUi(
        rideId: 1,
        title: 'Ride',
        dateTime: 'today',
        distanceKm: 0,
        hasRoute: false,
      ),
      onTap: () {},
    )));
    expect(find.byIcon(Icons.directions), findsNothing);
  });
}
