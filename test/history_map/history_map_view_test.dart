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
import 'package:retrail/features/history_map/map_activities.dart';
import 'package:retrail/features/history_map/map_area.dart';
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

  Future<void> pump(WidgetTester tester, {String? view, String? own}) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'history_view': ?view,
      // An activity that never occurs in these rides: the map starts on all.
      'last_activity_type': own ?? 'MOUNTAINBOARD',
    });
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

  testWidgets('the rides of one route share one card with the best ride', (
    tester,
  ) async {
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
    // One route, one card: no pager, the best ride, a count that opens the group.
    expect(find.text('1/${ActivityType.values.length}'), findsNothing);
    expect(find.text('Faster follow'), findsOneWidget);
    expect(find.text('Original'), findsNothing);
    expect(find.text('Best time'), findsOneWidget);
    expect(find.text('2 rides'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    expect(find.text('2 rides'), findsNothing);
    await finish(tester);
  });

  testWidgets('a ride the map filter hides loses its card', (tester) async {
    await _ride(db, title: 'Board ride', type: 'LONGBOARD');
    await _ride(db, title: 'Powder day', type: 'SKI', date: 2);
    await pump(tester, view: 'map');
    await settle(tester);
    container.read(mapSelectionProvider.notifier).tap(_tap, 14);
    await settle(tester);
    expect(find.text('Powder day'), findsOneWidget);

    container.read(mapActivitiesProvider.notifier).set({
      ActivityType.longboard,
    });
    await settle(tester);
    expect(find.text('Powder day'), findsNothing);
    expect(find.text('Board ride'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('overlapping routes under the tap give one card, no paging', (
    tester,
  ) async {
    await _ride(db, title: 'Alpha', date: 2);
    await _ride(db, title: 'Beta', date: 1);
    await pump(tester, view: 'map');
    await settle(tester);

    container.read(mapSelectionProvider.notifier).tap(_tap, 14);
    await settle(tester);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsNothing);
    expect(find.byTooltip('Next route'), findsNothing);

    await tester.fling(
      find.byType(MapPreviewCard),
      const Offset(-300, 0),
      1000,
    );
    await tester.pump();
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsNothing);
    await finish(tester);
  });

  testWidgets(
    'unticking a type in the activity menu leaves the list as it is',
    (tester) async {
      await _ride(db, title: 'Board ride', type: 'LONGBOARD');
      await _ride(db, title: 'Powder day', type: 'SKI', date: 2);
      await pump(tester, view: 'map');
      await settle(tester);

      expect(
        find.text(
          '${ActivityType.values.length}/${ActivityType.values.length}',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Activities'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ski'));
      await tester.pumpAndSettle();
      // The menu stays open while ticking; the button shows the new count.
      expect(find.text('Ski'), findsOneWidget);
      expect(
        find.text(
          '${ActivityType.values.length - 1}/${ActivityType.values.length}',
        ),
        findsOneWidget,
      );
      expect(
        container.read(mapActivitiesProvider),
        ActivityType.values.toSet()..remove(ActivityType.ski),
      );
      await tester.tap(find.byTooltip('Activities'));
      await tester.pumpAndSettle();
      await settle(tester);
      await tester.tap(find.text('List'));
      await settle(tester);

      // The History list has its own activity filter, untouched.
      expect(container.read(historyFilterProvider).activities, isEmpty);
      expect(find.text('Board ride'), findsOneWidget);
      expect(find.text('Powder day'), findsOneWidget);
      await finish(tester);
    },
  );

  testWidgets('followed rides are not counted, only unique routes', (
    tester,
  ) async {
    final original = await _ride(db, title: 'Hill run');
    await _ride(db, title: 'Hill run again', followed: original, date: 2);
    await _ride(db, title: 'Zeta', date: 3);
    await pump(tester, view: 'map');
    await settle(tester);

    container.read(historyFilterProvider.notifier).setQuery('Hill');
    await settle(tester);
    expect(find.text('1 of 2 rides'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('a header search that hides rides shows "n of m rides"', (
    tester,
  ) async {
    await _ride(db, title: 'Alpha ride');
    await _ride(db, title: 'Beta ride', date: 2);
    await pump(tester, view: 'map');
    await settle(tester);
    expect(find.text('1 of 2 rides'), findsNothing);

    container.read(historyFilterProvider.notifier).setQuery('Alpha');
    await settle(tester);
    expect(find.text('1 of 2 rides'), findsOneWidget);

    container.read(historyFilterProvider.notifier).setQuery('');
    await settle(tester);
    expect(find.text('1 of 2 rides'), findsNothing);
    await finish(tester);
  });

  testWidgets('the header activity filter does not hide rides on the map', (
    tester,
  ) async {
    await _ride(db, title: 'Board ride', type: 'LONGBOARD');
    await _ride(db, title: 'Powder day', type: 'SKI', date: 2);
    await pump(tester, view: 'map');
    await settle(tester);
    container
        .read(historyFilterProvider.notifier)
        .toggleActivity(ActivityType.ski);
    await settle(tester);
    // No "n of m" line: the activity filter is not one the map uses.
    expect(find.textContaining(' of 2 rides'), findsNothing);
    expect(
      find.text('${ActivityType.values.length}/${ActivityType.values.length}'),
      findsOneWidget,
    );
    await finish(tester);
  });

  testWidgets('the map opens on the rider\'s own activity, still changeable', (
    tester,
  ) async {
    await _ride(db, title: 'Board ride', type: 'LONGBOARD');
    await _ride(db, title: 'Powder day', type: 'SKI', date: 2);
    await pump(tester, view: 'map', own: 'SKI');
    await settle(tester);

    expect(find.text('1/${ActivityType.values.length}'), findsOneWidget);
    expect(container.read(mapActivitiesProvider), {ActivityType.ski});
    // The list is not narrowed by it.
    expect(container.read(historyFilterProvider).activities, isEmpty);

    // Tick the other one on, then the own one off: the rider decides.
    await tester.tap(find.byTooltip('Activities'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Longboard'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ski'));
    await tester.pumpAndSettle();
    expect(container.read(mapActivitiesProvider), {ActivityType.longboard});
    await finish(tester);
  });

  testWidgets('the all row ticks every type or none, the last one can go too', (
    tester,
  ) async {
    await _ride(db, title: 'Board ride', type: 'LONGBOARD');
    await _ride(db, title: 'Powder day', type: 'SKI', date: 2);
    await pump(tester, view: 'map');
    await settle(tester);

    await tester.tap(find.byTooltip('Activities'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All activities'));
    await tester.pumpAndSettle();
    expect(find.text('0/${ActivityType.values.length}'), findsOneWidget);
    expect(container.read(mapActivitiesProvider), isEmpty);
    await tester.tap(find.text('All activities'));
    await tester.pumpAndSettle();
    expect(
      find.text('${ActivityType.values.length}/${ActivityType.values.length}'),
      findsOneWidget,
    );
    expect(container.read(mapActivitiesProvider), isNull);

    // One type on, then off again: nothing is switched back on behind it.
    await tester.tap(find.text('Ski'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Longboard'));
    await tester.pumpAndSettle();
    expect(
      container.read(mapActivitiesProvider),
      ActivityType.values.toSet()
        ..remove(ActivityType.ski)
        ..remove(ActivityType.longboard),
    );
    await finish(tester);
  });

  group('camera framing', () {
    OverviewMap map(WidgetTester tester) =>
        tester.widget<OverviewMap>(find.byType(OverviewMap));

    testWidgets('a header filter change frames the new set, once', (
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

      container.read(historyFilterProvider.notifier).setQuery('North');
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

    testWidgets('a slow new set after a filter change still frames', (
      tester,
    ) async {
      OverviewMap.debugMapBuilderOverride = (_) => const SizedBox();
      await _ride(db, title: 'South', type: 'LONGBOARD', lat: 48);
      await _ride(db, title: 'North', type: 'SKI', lat: 52, date: 2);
      await pump(tester, view: 'map');
      await settle(tester);
      final first = map(tester).frameToken;

      container.read(historyFilterProvider.notifier).setQuery('North');
      // Seconds pass on the clock before the new set is through.
      await tester.pump(const Duration(seconds: 3));
      await settle(tester);
      expect(map(tester).frameToken, isNot(first));
      expect(map(tester).bounds!.south, 52);
      await finish(tester);
    });

    testWidgets('a gesture before the new set arrives cancels the frame', (
      tester,
    ) async {
      OverviewMap.debugMapBuilderOverride = (_) => const SizedBox();
      await _ride(db, title: 'South', type: 'LONGBOARD', lat: 48);
      await _ride(db, title: 'North', type: 'SKI', lat: 52, date: 2);
      await pump(tester, view: 'map');
      await settle(tester);
      final first = map(tester).frameToken;

      container.read(historyFilterProvider.notifier).setQuery('North');
      map(tester).onUserMoved!();
      await settle(tester);
      expect(map(tester).bounds!.south, 52);
      expect(map(tester).frameToken, first);
      await finish(tester);
    });

    testWidgets('a filter change that keeps the set leaves no frame waiting', (
      tester,
    ) async {
      OverviewMap.debugMapBuilderOverride = (_) => const SizedBox();
      await _ride(db, title: 'South', type: 'LONGBOARD', lat: 48);
      await _ride(db, title: 'North', type: 'SKI', lat: 52, date: 2);
      await pump(tester, view: 'map');
      await settle(tester);
      final first = map(tester).frameToken;

      // Both titles contain "th": the same rides stay.
      container.read(historyFilterProvider.notifier).setQuery('th');
      await settle(tester);
      expect(map(tester).frameToken, first);
      // A later change of the set by the activity menu does not frame.
      container.read(mapActivitiesProvider.notifier).set({ActivityType.ski});
      await settle(tester);
      expect(map(tester).bounds!.south, 52);
      expect(map(tester).frameToken, first);
      await finish(tester);
    });

    testWidgets('ticking activities never moves the camera', (tester) async {
      OverviewMap.debugMapBuilderOverride = (_) => const SizedBox();
      await _ride(db, title: 'South', type: 'LONGBOARD', lat: 48);
      await _ride(db, title: 'North', type: 'SKI', lat: 52, date: 2);
      await pump(tester, view: 'map');
      await settle(tester);
      final first = map(tester).frameToken;

      final n = container.read(mapActivitiesProvider.notifier);
      for (final types in <Set<ActivityType>?>[
        {ActivityType.ski},
        {ActivityType.longboard},
        <ActivityType>{},
        null,
      ]) {
        n.set(types);
        await settle(tester);
        expect(map(tester).frameToken, first, reason: '$types');
      }
      await finish(tester);
    });

    testWidgets('the start on my own activity frames its rides once', (
      tester,
    ) async {
      OverviewMap.debugMapBuilderOverride = (_) => const SizedBox();
      await _ride(db, title: 'South', type: 'LONGBOARD', lat: 48);
      await _ride(db, title: 'North', type: 'SKI', lat: 52, date: 2);
      await pump(tester, view: 'map', own: 'SKI');
      await settle(tester);
      expect(container.read(mapActivitiesProvider), {ActivityType.ski});
      expect(map(tester).bounds!.south, 52);
      expect(map(tester).frameToken, greaterThan(0));
      await finish(tester);
    });

    testWidgets('moving the radius does not move the camera', (tester) async {
      OverviewMap.debugMapBuilderOverride = (_) => const SizedBox();
      await _ride(db);
      await pump(tester, view: 'map');
      await settle(tester);
      container.read(mapAreaProvider.notifier).setPin((lat: 48.0, lng: 11.0));
      await settle(tester);
      final framed = map(tester).frameToken;
      container.read(mapAreaProvider.notifier).setRadius(20);
      await settle(tester);
      expect(map(tester).frameToken, framed);
      await finish(tester);
    });
  });

  group('camera memory', () {
    OverviewMap map(WidgetTester tester) =>
        tester.widget<OverviewMap>(find.byType(OverviewMap));

    testWidgets('leaving the map and coming back restores the camera', (
      tester,
    ) async {
      OverviewMap.debugMapBuilderOverride = (_) => const SizedBox();
      await _ride(db);
      await pump(tester, view: 'map');
      await settle(tester);
      expect(map(tester).restoreCamera, isNull);

      map(tester).onCameraIdle!((lat: 48.5, lng: 11.7), 12.5);
      await tester.tap(find.text('List'));
      await settle(tester);
      expect(find.byType(OverviewMap), findsNothing);

      await tester.tap(find.text('Map'));
      await settle(tester);
      expect(map(tester).restoreCamera, (
        center: (lat: 48.5, lng: 11.7),
        zoom: 12.5,
      ));
      await finish(tester);
    });
  });
}
