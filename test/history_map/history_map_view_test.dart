import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/connectivity/connectivity_providers.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:retrail/domain/ride_outline.dart';
import 'package:retrail/features/active_ride/active_ride_providers.dart';
import 'package:retrail/features/history/history_filter.dart';
import 'package:retrail/features/history/history_providers.dart';
import 'package:retrail/features/history/history_screen.dart';
import 'package:retrail/features/history_map/map_selection.dart';
import 'package:retrail/features/history_map/widgets/map_preview_card.dart';
import 'package:retrail/l10n/app_localizations.dart';
import 'package:retrail/domain/activity_type.dart';
import 'package:retrail/map/overview_map.dart';
import 'package:retrail/map/preview_snapshot.dart' show PreviewResult;
import 'package:retrail/map/route_preview_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _tap = (lat: 48.0, lng: 11.005);

Future<int> _ride(
  AppDatabase db, {
  String title = 'Ride',
  int? followed,
  int durationMs = 1000,
  double? coverage,
  int date = 1,
  String? type,
  double lat = 48,
}) async {
  final id = await db.rideDao.insert(
    RidesCompanion.insert(
      description: Value(title),
      typ: Value(type),
      startTime: Value(date),
      endTime: Value(date + durationMs),
      date: Value(date),
      hasRoute: const Value(true),
      durationMs: Value(durationMs),
      distanceMetres: const Value(1000),
      avgSpeedKmh: const Value(10),
      maxSpeedKmh: const Value(20),
      followedRideId: Value(followed),
      followCoverage: Value(coverage),
    ),
  );
  final o = RideOutline([(lat: lat, lng: 11.0), (lat: lat, lng: 11.01)]);
  final b = o.bounds!;
  await db.outlineDao.upsert(
    RideOutlinesCompanion.insert(
      rideId: Value(id),
      polyline: o.encode(),
      south: b.south,
      west: b.west,
      north: b.north,
      east: b.east,
    ),
  );
  return id;
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.memory();
    OverviewMap.debugMapBuilderOverride = (_) => const Text('native map');
  });
  tearDown(() async {
    OverviewMap.debugMapBuilderOverride = null;
    container.dispose();
    await db.close();
  });

  Future<void> pump(WidgetTester tester, {String? view}) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'history_view': ?view});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        preferencesRepositoryProvider.overrideWithValue(
          PreferencesRepository(prefs),
        ),
        previewCacheDirProvider.overrideWithValue(Directory.systemTemp),
        isOnlineProvider.overrideWith((ref) => Stream.value(true)),
        routePreviewCacheProvider.overrideWithValue(
          RoutePreviewCache(
            baseDir: Directory.systemTemp,
            render: (_, _) async => PreviewResult(Uint8List(0), complete: true),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(body: HistoryScreen()),
        ),
      ),
    );
    await tester.pump();
  }

  /// Unmounts the screen and lets the debounce and Drift timers run out.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  /// Lets timers, isolates and streams settle in real time.
  Future<void> settle(WidgetTester tester) async {
    // Debounce timers run on the fake clock, isolates and queries in real
    // time: alternate between the two until the map data is through.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
    }
    await tester.pump();
  }

  testWidgets('the list is the default and the switch opens the map', (
    tester,
  ) async {
    await _ride(db, title: 'Evening roll');
    await pump(tester);
    await settle(tester);
    expect(find.text('Evening roll'), findsOneWidget);
    expect(find.text('native map'), findsNothing);

    await tester.tap(find.text('Map'));
    await settle(tester);
    expect(find.text('native map'), findsOneWidget);
    expect(find.text('Evening roll'), findsNothing);
    await finish(tester);
  });

  testWidgets('a stored map choice comes back when the screen is rebuilt', (
    tester,
  ) async {
    await _ride(db);
    await pump(tester, view: 'map');
    await settle(tester);
    expect(find.text('native map'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('an empty history says so and offers no map', (tester) async {
    await pump(tester, view: 'map');
    await settle(tester);
    expect(find.text('No rides yet'), findsOneWidget);
    expect(find.text('native map'), findsNothing);
    await finish(tester);
  });

  testWidgets(
    'tapping the map shows the best ride first, pages with n/m and closes',
    (tester) async {
      final original = await _ride(db, title: 'Original', durationMs: 900);
      await _ride(
        db,
        title: 'Faster follow',
        followed: original,
        durationMs: 800,
        coverage: 1,
        date: 2,
      );
      await pump(tester, view: 'map');
      await settle(tester);

      container.read(mapSelectionProvider.notifier).tap(_tap, 14);
      await settle(tester);
      expect(find.text('1/2'), findsOneWidget);
      expect(find.text('2 rides on this route'), findsOneWidget);
      // The newest ride is first, and it is the group's best time.
      expect(find.text('Faster follow'), findsOneWidget);
      expect(find.text('Best time'), findsOneWidget);

      await tester.fling(
        find.byType(MapPreviewCard),
        const Offset(-300, 0),
        1000,
      );
      await tester.pump();
      expect(find.text('2/2'), findsOneWidget);
      expect(find.text('Original'), findsOneWidget);
      expect(find.text('Best time'), findsNothing);
      expect(find.text('2 rides on this route'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pump();
      expect(find.text('2/2'), findsNothing);
      await finish(tester);
    },
  );

  testWidgets('hiding a type in the legend hides it in the list too', (
    tester,
  ) async {
    await _ride(db, title: 'Board ride', type: 'LONGBOARD');
    await _ride(db, title: 'Powder day', type: 'SKI', date: 2);
    await pump(tester, view: 'map');
    await settle(tester);

    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Ski',
      ),
    );
    await settle(tester);
    await tester.tap(find.text('List'));
    await settle(tester);

    expect(find.text('Board ride'), findsOneWidget);
    expect(find.text('Powder day'), findsNothing);
    await finish(tester);
  });

  group('camera framing', () {
    OverviewMap map(WidgetTester tester) =>
        tester.widget<OverviewMap>(find.byType(OverviewMap));

    testWidgets('a filter change frames the new set, once, with its bounds', (
      tester,
    ) async {
      // The native map is replaced, but the OverviewMap widget stays in the
      // tree: its inputs are what the camera follows.
      OverviewMap.debugMapBuilderOverride = (_) => const SizedBox();
      await _ride(db, title: 'South', type: 'LONGBOARD', lat: 48);
      await _ride(db, title: 'North', type: 'SKI', lat: 52, date: 2);
      await pump(tester, view: 'map');
      await settle(tester);
      final first = map(tester).frameToken;
      expect(map(tester).bounds!.south, 48);

      container
          .read(historyFilterProvider.notifier)
          .toggleActivity(ActivityType.ski);
      await settle(tester);
      expect(map(tester).frameToken, isNot(first));
      expect(map(tester).bounds!.south, 52);
      final framed = map(tester).frameToken;

      // Not filters that select rides: sort, a favourite, a radius.
      container
          .read(historyFilterProvider.notifier)
          .setSort(SortOrder.distance);
      await settle(tester);
      expect(map(tester).frameToken, framed);
      await finish(tester);
    });

    testWidgets('moving the radius does not move the camera', (tester) async {
      OverviewMap.debugMapBuilderOverride = (_) => const SizedBox();
      await _ride(db);
      await pump(tester, view: 'map');
      await settle(tester);
      container.read(historyFilterProvider.notifier).setAreaPin((
        lat: 48.0,
        lng: 11.0,
      ));
      await settle(tester);
      final framed = map(tester).frameToken;
      container.read(historyFilterProvider.notifier).setAreaRadius(20);
      await settle(tester);
      expect(map(tester).frameToken, framed);
      await finish(tester);
    });
  });
}
