import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/db/ride_with_trackpoints.dart';
import 'package:retrail/domain/activity_type.dart';
import 'package:retrail/domain/ride_stats.dart';
import 'package:retrail/features/history/edit_ride_dialog.dart';
import 'package:retrail/features/history/ride_detail_dialog.dart';
import 'package:retrail/l10n/app_localizations.dart';
import 'package:retrail/map/live_map.dart';

import '../support/live_map_stub.dart';

Widget _host(Widget child, {Locale? locale}) => MaterialApp(
      locale: locale,
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

Ride _ride() => const Ride(
      rideId: 1,
      description: 'Morning roll',
      typ: 'LONGBOARD',
      startTime: 0,
      endTime: 600000,
      date: 1718193600000,
      comment: 'felt great',
      isFavorite: false,
      favoritedAt: null,
      hasRoute: false,
    );

void main() {
  useStubLiveMap();

  group('EditRideDialog', () {
    testWidgets('renders and Save fires with entered values', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? savedTitle;
      ActivityType? savedType;
      await tester.pumpWidget(_host(EditRideDialog(
        initialDescription: 'Old title',
        initialType: ActivityType.longboard,
        onDismiss: () {},
        onSave: (t, c, type) {
          savedTitle = t;
          savedType = type;
        },
      )));
      expect(find.text('Edit ride'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'New title');
      // Toggle the longboard chip off (selected → null).
      await tester.tap(find.text('Longboard'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      expect(savedTitle, 'New title');
      expect(savedType, isNull);
    });

    testWidgets(
        'activity chips draw no checkmark over their glyph (issue #29) — '
        'selection shows through the chip fill instead', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_host(EditRideDialog(
        initialType: ActivityType.skateboard,
        onDismiss: () {},
        onSave: (_, _, _) {},
      )));

      final chips = tester.widgetList<FilterChip>(find.byType(FilterChip));
      expect(chips, hasLength(ActivityType.values.length));
      expect(chips.every((c) => c.showCheckmark == false), isTrue);
    });
  });

  group('RideDetailDialog', () {
    testWidgets('shows stats and the no-route placeholder when empty',
        (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var dismissed = false;
      await tester.pumpWidget(_host(RideDetailDialog(
        rwt: RideWithTrackpoints(ride: _ride(), trackpoints: const []),
        stats: const RideStats(
            durationMs: 600000,
            distanceMetres: 4200,
            maxSpeedKmh: 22,
            avgSpeedKmh: 15),
        onDismiss: () => dismissed = true,
      )));

      expect(find.text('No route'), findsOneWidget); // empty trackpoints
      expect(find.text('4.20 km'), findsOneWidget);
      expect(find.text('22.0 km/h'), findsOneWidget); // top speed
      expect(find.text('15.0 km/h'), findsOneWidget); // avg speed
      expect(find.text('felt great'), findsOneWidget);

      await tester.tap(find.text('Close'));
      expect(dismissed, isTrue);
    });

    testWidgets('frames the whole route (fitBounds) instead of the endpoint',
        (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_host(RideDetailDialog(
        rwt: RideWithTrackpoints(ride: _ride(), trackpoints: const [
          Trackpoint(
              trackpointId: 0,
              rideId: 1,
              latitude: 52.0,
              longitude: 13.0,
              timestamp: 0),
          Trackpoint(
              trackpointId: 1,
              rideId: 1,
              latitude: 52.02,
              longitude: 13.0,
              timestamp: 1),
        ]),
        stats: const RideStats(
            durationMs: 600000,
            distanceMetres: 4200,
            maxSpeedKmh: 22,
            avgSpeedKmh: 15),
        onDismiss: () {},
      )));

      final map = tester.widget<LiveMap>(find.byType(LiveMap));
      expect(map.fitBounds, isTrue); // whole route, not centred on the last point
    });
  });

  testWidgets('RideDetailDialog: German uses the decimal comma in its stats',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_host(
        RideDetailDialog(
          rwt: RideWithTrackpoints(ride: _ride(), trackpoints: const []),
          stats: const RideStats(
              durationMs: 600000,
              distanceMetres: 4200,
              maxSpeedKmh: 22,
              avgSpeedKmh: 15),
          onDismiss: () {},
        ),
        locale: const Locale('de')));
    expect(find.text('4,20 km'), findsOneWidget);
    expect(find.text('22,0 km/h'), findsOneWidget);
    expect(find.text('15,0 km/h'), findsOneWidget);
  });
}
