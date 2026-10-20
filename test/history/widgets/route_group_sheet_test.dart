import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/domain/ride_stats.dart';
import 'package:retrail/domain/route_group.dart';
import 'package:retrail/features/history/history_items.dart';
import 'package:retrail/features/history/route_group_providers.dart';
import 'package:retrail/features/history/widgets/route_group_sheet.dart';
import 'package:retrail/l10n/app_localizations.dart';

// 2024-06-12 12:00 UTC-ish; the rows show `dd.MM.yyyy  HH:mm`.
const _day = 86400000;
const _t0 = 1718193600000;

RideEntryItem _entry(
  int id, {
  String? title,
  int at = _t0,
  int durationMs = 600000,
  double distanceMetres = 4200,
  int? followed,
  double? coverage,
}) => RideEntryItem(
  Ride(
    rideId: id,
    description: title,
    date: at,
    isFavorite: false,
    hasRoute: true,
    followedRideId: followed,
    followCoverage: coverage,
  ),
  RideStats(
    durationMs: durationMs,
    distanceMetres: distanceMetres,
    maxSpeedKmh: 25,
    avgSpeedKmh: 15,
  ),
);

RouteGroupRide _groupRide(RideEntryItem e) => RouteGroupRide(
  rideId: e.ride.rideId,
  timestampMs: e.ride.date!,
  durationMs: e.stats.durationMs,
  coverage: e.ride.followCoverage,
);

/// Original 1 ("Hausrunde"), complete follows 2 (fastest) and 3, partial 4.
RouteGroupView _view() {
  final entries = [
    _entry(1, title: 'Hausrunde', durationMs: 900000),
    _entry(2, at: _t0 + _day, durationMs: 800000, followed: 1, coverage: 1),
    _entry(3, at: _t0 + 2 * _day, durationMs: 850000, followed: 1, coverage: 1),
    _entry(
      4,
      at: _t0 + 3 * _day,
      durationMs: 100000,
      distanceMetres: 2100,
      followed: 1,
      coverage: 0.5,
    ),
  ];
  return RouteGroupView(
    buildRouteGroup(_groupRide(entries.first), [
      for (final e in entries.skip(1)) _groupRide(e),
    ]),
    {for (final e in entries) e.ride.rideId: e},
  );
}

void main() {
  RideEntryItem? opened;

  Future<void> pump(
    WidgetTester tester, {
    RouteGroupView? view,
    int highlight = 3,
  }) async {
    opened = null;
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final shown = view ?? _view();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routeGroupProvider.overrideWith((ref, _) => Stream.value(shown)),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RouteGroupSheet(
              rootId: 1,
              highlightRideId: highlight,
              onOpenRide: (e) => opened = e,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder row(int id) => find.byKey(ValueKey('route_group_row_$id'));

  testWidgets('the header names the original and its distance', (tester) async {
    await pump(tester);
    expect(find.text('Hausrunde'), findsOneWidget);
    expect(find.text('4.2 km'), findsOneWidget);
  });

  testWidgets('lists the original, the complete and the partial follows', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('ORIGINAL'), findsOneWidget);
    expect(find.text('FOLLOWED (2)'), findsOneWidget);
    expect(find.text('PARTIAL — NO BEST TIME'), findsOneWidget);
    for (final id in [1, 2, 3, 4]) {
      expect(row(id), findsOneWidget);
    }
    // Complete follows in date order, the partial one after them.
    final y = [
      for (final id in [1, 2, 3, 4]) tester.getTopLeft(row(id)).dy,
    ];
    expect(y, orderedEquals([...y]..sort()));
  });

  testWidgets('a row shows the distance, the duration and the average speed', (
    tester,
  ) async {
    await pump(tester);
    expect(
      find.descendant(
        of: row(4),
        matching: find.text('2.1 km · 01:40 · Ø 15 km/h'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('only the best time has the trophy', (tester) async {
    await pump(tester);
    final trophy = find.byIcon(Icons.emoji_events);
    expect(trophy, findsOneWidget);
    expect(find.descendant(of: row(2), matching: trophy), findsOneWidget);
    expect(tester.widget<Icon>(trophy).semanticLabel, 'Best time');
  });

  testWidgets('the ride the sheet was opened from is selected', (tester) async {
    await pump(tester, highlight: 3);
    expect(tester.widget<ListTile>(row(3)).selected, isTrue);
    expect(tester.widget<ListTile>(row(2)).selected, isFalse);
  });

  testWidgets('tapping a row opens that ride', (tester) async {
    await pump(tester);
    await tester.tap(row(4));
    await tester.pump();
    expect(opened!.ride.rideId, 4);
  });

  testWidgets('no partial follows: no partial section', (tester) async {
    final entries = [
      _entry(1, title: 'Hausrunde'),
      _entry(2, at: _t0 + _day, followed: 1, coverage: 1),
    ];
    await pump(
      tester,
      view: RouteGroupView(
        buildRouteGroup(_groupRide(entries[0]), [_groupRide(entries[1])]),
        {for (final e in entries) e.ride.rideId: e},
      ),
      highlight: 2,
    );
    expect(find.text('PARTIAL — NO BEST TIME'), findsNothing);
    expect(find.text('FOLLOWED (1)'), findsOneWidget);
  });
}
