import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:retrail/core/connectivity/connectivity_providers.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:retrail/domain/ride_outline.dart';
import 'package:retrail/features/active_ride/active_ride_providers.dart';
import 'package:retrail/features/history/history_providers.dart';
import 'package:retrail/features/history/history_screen.dart';
import 'package:retrail/features/history_map/map_area.dart';
import 'package:retrail/features/history_map/map_selection.dart';
import 'package:retrail/features/place_search/photon_client.dart';
import 'package:retrail/features/place_search/place_search_controller.dart';
import 'package:retrail/l10n/app_localizations.dart';
import 'package:retrail/map/overview_map.dart';
import 'package:retrail/map/preview_snapshot.dart';
import 'package:retrail/map/route_preview_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _hamburg =
    '{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"Point","coordinates":[9.99,53.55]},"properties":{"name":"Hamburg","country":"Germany"}}]}';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late List<Uri> sent;

  setUp(() {
    db = AppDatabase.memory();
    sent = [];
    OverviewMap.debugMapBuilderOverride = (_) => const Text('native map');
  });
  tearDown(() async {
    OverviewMap.debugMapBuilderOverride = null;
    container.dispose();
    await db.close();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final id = await db.rideDao.insert(
      RidesCompanion.insert(
        description: const Value('Board ride'),
        startTime: const Value(1),
        date: const Value(1),
        hasRoute: const Value(true),
      ),
    );
    final outline = RideOutline([
      (lat: 48.0, lng: 11.0),
      (lat: 48.0, lng: 11.01),
    ]);
    final box = outline.bounds!;
    await db.outlineDao.upsert(
      RideOutlinesCompanion.insert(
        rideId: Value(id),
        polyline: outline.encode(),
        south: box.south,
        west: box.west,
        north: box.north,
        east: box.east,
      ),
    );
    SharedPreferences.setMockInitialValues({
      'history_view': 'map',
      'last_activity_type': 'MOUNTAINBOARD',
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
        placeSearchDebounceProvider.overrideWithValue(
          const Duration(milliseconds: 50),
        ),
        photonClientProvider.overrideWithValue(
          PhotonClient(
            client: MockClient((req) async {
              sent.add(req.url);
              return http.Response(_hamburg, 200);
            }),
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
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
    }
    await tester.pump();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('the magnifier opens the field, a chosen place sets the pin', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('native map'), findsOneWidget);

    await tester.tap(find.byTooltip('Search a place'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search by Photon · © OpenStreetMap'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Ha');
    await tester.pump(const Duration(milliseconds: 100));
    expect(sent, isEmpty);

    await tester.enterText(find.byType(TextField), 'Hamb');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(sent, hasLength(1));
    expect(sent.single.queryParameters['q'], 'Hamb');
    expect(sent.single.queryParameters['lang'], 'en');
    expect(find.text('Hamburg'), findsOneWidget);

    await tester.tap(find.text('Hamburg'));
    await tester.pump();
    final area = container.read(mapAreaProvider);
    expect(area?.pin, (lat: 53.55, lng: 9.99));
    expect(area?.radiusKm, 5);
    expect(find.byType(TextField), findsNothing);
    // The header ride search is untouched.
    expect(container.read(historyFilterProvider).query, '');
    await finish(tester);
  });

  testWidgets('closing the field leaves the map as it is', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Search a place'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close search'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(container.read(mapAreaProvider), isNull);
    expect(find.byTooltip('Search a place'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('opening the search closes an open ride card', (tester) async {
    await pump(tester);
    container.read(mapSelectionProvider.notifier).tap((
      lat: 48.0,
      lng: 11.005,
    ), 14);
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(mapSelectionProvider).rideIds, isNotEmpty);

    await tester.tap(find.byTooltip('Search a place'));
    await tester.pumpAndSettle();
    expect(container.read(mapSelectionProvider).rideIds, isEmpty);
    expect(find.byType(TextField), findsOneWidget);
    await finish(tester);
  });
}
