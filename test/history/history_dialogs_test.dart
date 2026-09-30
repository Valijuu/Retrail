import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_colors.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/db/ride_with_trackpoints.dart';
import 'package:retrail/domain/activity_type.dart';
import 'package:retrail/domain/ride_stats.dart';
import 'package:retrail/features/history/edit_ride_sheet.dart';
import 'package:retrail/features/history/ride_detail_dialog.dart';
import 'package:retrail/l10n/app_localizations.dart';
import 'package:retrail/map/live_map.dart';

import '../support/live_map_stub.dart';

Widget _host(Widget child,
        {Locale? locale, Brightness brightness = Brightness.light}) =>
    MaterialApp(
      locale: locale,
      theme: buildTheme(brightness),
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

  group('EditRideSheet', () {
    testWidgets('renders and Save fires with entered values', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? savedTitle;
      ActivityType? savedType;
      await tester.pumpWidget(_host(EditRideSheet(
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

      await tester.pumpWidget(_host(EditRideSheet(
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

    testWidgets(
        'the activity row wraps instead of overflowing at 320 px, text scale '
        '2.0, German (issue #46)', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_host(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2.0)),
            child: RideDetailDialog(
              rwt: RideWithTrackpoints(ride: _ride(), trackpoints: const []),
              // Single-digit speeds: with the Ahem test font (1 em per glyph)
              // a "22,0 km/h" value alone is wider than the dialog, which
              // real fonts are not.
              stats: const RideStats(
                  durationMs: 600000,
                  distanceMetres: 4200,
                  maxSpeedKmh: 9,
                  avgSpeedKmh: 5),
              onDismiss: () {},
            ),
          ),
        ),
        locale: const Locale('de'),
      ));

      expect(find.text('Longboard'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'on a small screen (iPhone 8) the Close button stays visible and '
        'tappable', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var dismissed = false;
      await tester.pumpWidget(_host(
        RideDetailDialog(
          rwt: RideWithTrackpoints(
            ride: _ride().copyWith(
                comment: const Value('Lange Runde am Rhein entlang, erst '
                    'Rückenwind, dann Gegenwind, zweimal Pause am Kiosk.')),
            trackpoints: const [
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
            ],
          ),
          stats: const RideStats(
              durationMs: 600000,
              distanceMetres: 4200,
              maxSpeedKmh: 22,
              avgSpeedKmh: 15),
          onDismiss: () => dismissed = true,
        ),
        locale: const Locale('de'),
      ));

      final close = find.text('Schließen');
      expect(close, findsOneWidget);
      final rect = tester.getRect(close);
      expect(rect.bottom, lessThanOrEqualTo(667),
          reason: 'Close must not be pushed below the screen');
      await tester.tap(close);
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

    testWidgets('Follow route button shows with a route and fires',
        (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var followed = false;
      await tester.pumpWidget(_host(RideDetailDialog(
        rwt: RideWithTrackpoints(ride: _ride(), trackpoints: const [
          Trackpoint(
              trackpointId: 0,
              rideId: 1,
              latitude: 48.0,
              longitude: 11.0,
              timestamp: 0),
          Trackpoint(
              trackpointId: 1,
              rideId: 1,
              latitude: 48.001,
              longitude: 11.0,
              timestamp: 1),
        ]),
        stats: const RideStats(
            durationMs: 1, distanceMetres: 1, maxSpeedKmh: 1, avgSpeedKmh: 1),
        onDismiss: () {},
        onFollowRoute: () => followed = true,
      )));
      final button = find.widgetWithText(FilledButton, 'Follow route');
      expect(button, findsOneWidget);
      await tester.tap(button);
      expect(followed, isTrue);
      await tester.tap(find.byIcon(Icons.fullscreen));
      await tester.pumpAndSettle();
      expect(find.text('Follow route'), findsNothing);
    });

    for (final (name, n, cb) in [
      ('one trackpoint', 1, true),
      ('no callback', 2, false),
    ]) {
      testWidgets('no Follow route button: $name', (tester) async {
        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(_host(RideDetailDialog(
          rwt: RideWithTrackpoints(ride: _ride(), trackpoints: [
            for (var i = 0; i < n; i++)
              Trackpoint(
                  trackpointId: i,
                  rideId: 1,
                  latitude: 48.0 + i * 0.001,
                  longitude: 11.0,
                  timestamp: i),
          ]),
          stats: const RideStats(
              durationMs: 1, distanceMetres: 1, maxSpeedKmh: 1, avgSpeedKmh: 1),
          onDismiss: () {},
          onFollowRoute: cb ? () {} : null,
        )));
        expect(find.text('Follow route'), findsNothing);
      });
    }

    for (final (label, size, locale, text) in [
      ('en 600x900', const Size(600, 900), const Locale('en'), 'Follow route'),
      ('de 375x667', const Size(375, 667), const Locale('de'),
          'Strecke nachfahren'),
    ]) {
      testWidgets('Follow route label is not truncated ($label)',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(_host(
          RideDetailDialog(
            rwt: RideWithTrackpoints(ride: _ride(), trackpoints: const [
              Trackpoint(
                  trackpointId: 0,
                  rideId: 1,
                  latitude: 48.0,
                  longitude: 11.0,
                  timestamp: 0),
              Trackpoint(
                  trackpointId: 1,
                  rideId: 1,
                  latitude: 48.001,
                  longitude: 11.0,
                  timestamp: 1),
            ]),
            stats: const RideStats(
                durationMs: 1,
                distanceMetres: 1,
                maxSpeedKmh: 1,
                avgSpeedKmh: 1),
            onDismiss: () {},
            onFollowRoute: () {},
          ),
          locale: locale,
        ));
        expect(find.text(text), findsOneWidget);
        expect(
            tester.renderObject<RenderParagraph>(find.text(text)).didExceedMaxLines,
            isFalse);
      });
    }

    testWidgets('no Follow route button without a route or callback',
        (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_host(RideDetailDialog(
        rwt: RideWithTrackpoints(ride: _ride(), trackpoints: const []),
        stats: const RideStats(
            durationMs: 1, distanceMetres: 1, maxSpeedKmh: 1, avgSpeedKmh: 1),
        onDismiss: () {},
        onFollowRoute: () {},
      )));
      expect(find.text('Follow route'), findsNothing);
    });

    testWidgets(
        'fullscreen keeps the SAME map (state moves, no second native map '
        'to start) — there and back', (tester) async {
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
      final dialogMap = tester.state(find.byType(LiveMap));

      await tester.tap(find.byIcon(Icons.fullscreen));
      await tester.pump();
      expect(identical(tester.state(find.byType(LiveMap)), dialogMap), isTrue,
          reason: 'fullscreen must reuse the dialog map');

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(identical(tester.state(find.byType(LiveMap)), dialogMap), isTrue,
          reason: 'closing fullscreen must keep the same map');
    });

    testWidgets(
        'a rebuild hands the map (dialog and fullscreen) the SAME points '
        'list, so it does not re-push the route source (issue #42)',
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
      final before = tester.widget<LiveMap>(find.byType(LiveMap)).points;

      tester.element(find.byType(RideDetailDialog)).markNeedsBuild();
      await tester.pump();

      final after = tester.widget<LiveMap>(find.byType(LiveMap)).points;
      expect(identical(before, after), isTrue);

      // Fullscreen: same list as the dialog map, and stable across rebuilds.
      await tester.tap(find.byIcon(Icons.fullscreen));
      await tester.pump();
      final fullscreen = tester.widget<LiveMap>(find.byType(LiveMap)).points;
      expect(identical(before, fullscreen), isTrue);

      tester.element(find.byType(RideDetailDialog)).markNeedsBuild();
      await tester.pump();
      expect(
          identical(
              fullscreen, tester.widget<LiveMap>(find.byType(LiveMap)).points),
          isTrue);
    });

    for (final (brightness, palette) in [
      (Brightness.light, AppColors.light),
      (Brightness.dark, AppColors.dark),
    ]) {
      testWidgets(
          'fullscreen / close map buttons follow the theme '
          '(${brightness.name}), translucent over the map', (tester) async {
        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_host(
          RideDetailDialog(
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
          ),
          brightness: brightness,
        ));

        void expectThemed(IconData icon) {
          final button = find.byIcon(icon);
          final face = tester.widget<Material>(find.ancestor(
              of: button,
              matching: find.byWidgetPredicate(
                  (w) => w is Material && w.shape is CircleBorder)));
          // App-surface face like the live map's recenter button and compass —
          // but see-through, so it doesn't hide the map corner beneath it.
          expect(face.color!.withValues(alpha: 1), palette.surface);
          expect(face.color!.a, lessThan(1));
          expect(tester.widget<Icon>(button).color, palette.primary);
        }

        expectThemed(Icons.fullscreen);
        await tester.tap(find.byIcon(Icons.fullscreen));
        await tester.pump();
        expectThemed(Icons.close);
      });
    }
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
