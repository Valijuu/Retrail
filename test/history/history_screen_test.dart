import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/db/ride_dao.dart';
import 'package:retrail/data/db/trackpoint_dao.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/data/repositories/ride_repository.dart';
import 'package:retrail/data/repositories/trackpoint_repository.dart';
import 'package:retrail/domain/activity_type.dart';
import 'package:retrail/domain/ride_stats.dart';
import 'package:retrail/features/active_ride/active_ride_providers.dart';
import 'package:retrail/features/history/history_controller.dart';
import 'package:retrail/features/history/history_filter.dart';
import 'package:retrail/features/history/history_items.dart';
import 'package:retrail/features/history/history_providers.dart';
import 'package:retrail/features/history/history_ride_card.dart';
import 'package:retrail/features/history/history_screen.dart';
import 'package:retrail/features/shell/main_shell.dart';
import 'package:retrail/features/home/navigation_launcher.dart';
import 'package:retrail/l10n/app_localizations.dart';
import 'package:retrail/map/preview_projection.dart';
import 'package:retrail/map/preview_snapshot.dart' show PreviewResult;
import 'package:retrail/map/route_preview.dart';
import 'package:retrail/map/route_preview_cache.dart';

class FakeHistoryController extends HistoryController {
  FakeHistoryController(super.repo, super.cache);
  final calls = <String>[];
  @override
  Future<void> deleteRide(int id) async => calls.add('delete:$id');
  @override
  Future<void> deleteRides(Iterable<int> ids) async =>
      calls.add('deleteRides:${ids.toList()}');
  @override
  Future<void> updateRideDetails(
          int id, String? d, String? c, ActivityType? t) async =>
      calls.add('update:$id');
  @override
  Future<void> toggleFavorite(Ride ride) async =>
      calls.add('fav:${ride.rideId}');
}

/// Records which rides the screen pre-warms previews for (no real IO).
class WarmSpyCache extends RoutePreviewCache {
  WarmSpyCache()
      : super(
            baseDir: Directory.systemTemp,
            render: (_, _) async =>
                PreviewResult(Uint8List(0), complete: true));

  final warmed = <int>[];

  @override
  Future<File> ensurePreview(int rideId, List<RoutePoint> points,
      {required Brightness brightness}) async {
    warmed.add(rideId);
    return File('${Directory.systemTemp.path}/warm_$rideId.png');
  }
}

class FakeNavigationLauncher implements NavigationLauncher {
  final launches = <(double, double, String)>[];
  @override
  Future<void> launchTo(double lat, double lng, String label) async =>
      launches.add((lat, lng, label));
}

/// Serves canned trackpoints per ride id, synchronously (`Stream.value`) —
/// a card fetches its own trackpoints lazily now (issue #21), so tests feed
/// them through this instead of the pre-loaded `RideWithTrackpoints` the
/// list used to carry. `super(TrackpointDao(...))` is never actually queried.
class FakeTrackpointRepository extends TrackpointRepository {
  FakeTrackpointRepository(AppDatabase db, this._byRideId)
      : super(TrackpointDao(db));
  final Map<int, List<Trackpoint>> _byRideId;

  @override
  Stream<List<Trackpoint>> getForRide(int rideId) =>
      Stream.value(_byRideId[rideId] ?? const []);
}

Trackpoint _tp(int rideId, double lat, double lng) => Trackpoint(
      trackpointId: 0,
      rideId: rideId,
      latitude: lat,
      longitude: lng,
      timestamp: 0,
    );

/// A ride with a route (`hasRoute: true`); pass the same [trackpoints] map to
/// `pump(... trackpoints: ...)` so `_Thumbnail`'s/`_warmPreviews`'/the
/// navigate button's lazy fetch (issue #21) resolves real coordinates.
RideEntryItem _routedEntry(int id) => RideEntryItem(
      _ride(id, desc: 'Routed ride', hasRoute: true),
      const RideStats(
          durationMs: 600000, distanceMetres: 1200, maxSpeedKmh: 22, avgSpeedKmh: 15),
    );

Ride _ride(int id,
        {String? desc, String? typ, bool fav = false, bool hasRoute = false}) =>
    Ride(
      rideId: id,
      description: desc,
      typ: typ,
      startTime: 0,
      endTime: 600000, // 10 min
      date: 1718193600000,
      comment: null,
      isFavorite: fav,
      favoritedAt: null,
      hasRoute: hasRoute,
    );

RideEntryItem _entry(int id, {String? desc, String? typ, bool fav = false}) =>
    RideEntryItem(
      _ride(id, desc: desc, typ: typ, fav: fav),
      const RideStats(
          durationMs: 600000, distanceMetres: 4200, maxSpeedKmh: 22, avgSpeedKmh: 15),
    );

void main() {
  late AppDatabase db;
  late FakeHistoryController controller;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.memory();
    controller = FakeHistoryController(
      RideRepository(RideDao(db)),
      RoutePreviewCache(
          baseDir: Directory.systemTemp,
          render: (_, _) async => PreviewResult(Uint8List(0), complete: true)),
    );
  });
  tearDown(() {
    container.dispose();
    db.close();
  });

  Future<void> pump(
    WidgetTester tester,
    List<HistoryItem> items, {
    NavigationLauncher? navLauncher,
    int? presetTarget,
    RoutePreviewCache? previewCache,
    Map<int, List<Trackpoint>> trackpoints = const {},
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    container = ProviderContainer(overrides: [
      previewCacheDirProvider.overrideWithValue(Directory.systemTemp),
      // A card fetches its own trackpoints lazily now (issue #21).
      trackpointRepositoryProvider
          .overrideWithValue(FakeTrackpointRepository(db, trackpoints)),
      historyItemsProvider.overrideWith((ref) => Stream.value(items)),
      historyControllerProvider.overrideWithValue(controller),
      if (previewCache != null)
        routePreviewCacheProvider.overrideWithValue(previewCache),
      if (navLauncher != null)
        navigationLauncherProvider.overrideWithValue(navLauncher),
    ]);
    // Simulate Home parking a jump target *before* the History screen mounts
    // (the PageView builds it lazily on navigation).
    if (presetTarget != null) {
      container.read(historyTargetRideProvider.notifier).state = presetTarget;
    }

    await tester.pumpWidget(UncontrolledProviderScope(
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
        home: const Scaffold(body: HistoryScreen()),
      ),
    ));
    await tester.pump();
  }

  testWidgets('renders ride cards with title, distance, meta and chips',
      (tester) async {
    await pump(tester, [_entry(1, desc: 'Morning roll', typ: 'SCOOTER')]);
    expect(find.text('Morning roll'), findsOneWidget);
    expect(find.text('4.2 km'), findsOneWidget);
    expect(find.text('Great pace'), findsOneWidget); // avg 15 > 10
    expect(find.text('No route'), findsOneWidget); // empty trackpoints
    expect(find.text('Scooter'), findsOneWidget);
  });

  testWidgets('empty state when there are no rides', (tester) async {
    await pump(tester, const []);
    expect(find.text('No rides yet'), findsOneWidget);
  });

  testWidgets(
      'the filter sheet never grows above the top safe area, even once '
      'selecting several ACTIVITY TYPE chips wraps that section onto '
      'another line (regression: showModalBottomSheet needs useSafeArea)',
      (tester) async {
    await pump(tester, [_entry(1)]);

    // Simulate a phone status bar / notch after the initial pump (which
    // hard-codes its own physicalSize) — a real device always has this.
    tester.view.padding = const FakeViewPadding(top: 40);
    addTearDown(tester.view.resetPadding);
    await tester.pump();

    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();

    // Selecting several activity chips grows a checkmark on each (widening
    // them) until the ACTIVITY TYPE Wrap spills onto a second line — the
    // same layout-growth mechanism the period chips used to trigger before
    // they were removed. Chip order in the sheet: 4 SORT BY + 1 ACTIVITY
    // "All" + 7 ActivityType chips — tap 4 of the 7 real activity types
    // (skip "All", which clears instead of adding). As each tap grows the
    // sheet, tapping further down the list risks the target scrolling just
    // outside the pumped viewport, so this stays conservative.
    final chips = find.byType(FilterChip);
    for (var i = 5; i <= 8; i++) {
      await tester.tap(chips.at(i));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    final sheetTop = tester.getTopLeft(find.text('Filter')).dy;
    expect(sheetTop, greaterThanOrEqualTo(40));
  });

  testWidgets(
      'pre-warms previews for listed rides as soon as items load — '
      'not only when their card scrolls into view', (tester) async {
    final spy = WarmSpyCache();
    await pump(
      tester,
      [_routedEntry(1), _routedEntry(2), _entry(3)], // 3 has no route
      previewCache: spy,
      trackpoints: {
        1: [_tp(1, 52.0, 13.0), _tp(1, 52.01, 13.0)],
        2: [_tp(2, 52.0, 13.0), _tp(2, 52.01, 13.0)],
      },
    );
    await tester.pump(); // post-frame warm pass
    await tester.pump(); // lazy per-ride trackpoints fetch (issue #21) lands
    expect(spy.warmed, containsAll([1, 2]));
    expect(spy.warmed, isNot(contains(3))); // nothing to render for no-route
  });

  testWidgets('thumbnail top corners are clipped to the card radius '
      '(so the highlight border fits the corners)', (tester) async {
    await pump(tester, [_entry(1, desc: 'Morning roll')]);
    expect(
      find.byWidgetPredicate((w) =>
          w is ClipRRect &&
          w.borderRadius is BorderRadius &&
          (w.borderRadius as BorderRadius).topLeft == const Radius.circular(14) &&
          (w.borderRadius as BorderRadius).bottomLeft == Radius.zero),
      findsOneWidget,
    );
  });

  testWidgets('search toggle reveals the field and drives the query filter',
      (tester) async {
    await pump(tester, [_entry(1, desc: 'Morning roll')]);
    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'sunset');
    await tester.pump();
    expect(container.read(historyFilterProvider).query, 'sunset');
  });

  testWidgets('filter sheet chip updates the filter and the badge',
      (tester) async {
    await pump(tester, [_entry(1)]);
    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Longest distance'));
    await tester.pumpAndSettle();
    expect(container.read(historyFilterProvider).sort, SortOrder.distance);
  });

  testWidgets('Reset clears the search query and the visible field',
      (tester) async {
    await pump(tester, [_entry(1)]);
    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'foo');
    await tester.pump();
    expect(container.read(historyFilterProvider).query, 'foo');

    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(container.read(historyFilterProvider).query, '');
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
  });

  testWidgets('long-press enters selection; batch delete confirms',
      (tester) async {
    await pump(tester, [_entry(1), _entry(2)]);
    await tester.longPress(find.byType(HistoryRideCard).first);
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();
    expect(find.text('Delete ride'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(controller.calls, contains('deleteRides:[1]'));
  });

  testWidgets(
      '"select all" selects every visible ride; confirming delete removes '
      'exactly those', (tester) async {
    await pump(tester, [_entry(1), _entry(2), _entry(3)]);
    await tester.longPress(find.byType(HistoryRideCard).first);
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.select_all));
    await tester.pump();
    expect(find.text('3 selected'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(controller.calls, contains('deleteRides:[1, 2, 3]'));
  });

  testWidgets('3-dot menu Edit opens the edit dialog', (tester) async {
    await pump(tester, [_entry(1, desc: 'Morning roll')]);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit ride'), findsOneWidget);
  });

  testWidgets('3-dot menu Delete confirms and calls the controller',
      (tester) async {
    await pump(tester, [_entry(7, desc: 'Morning roll')]);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete')); // confirm
    await tester.pumpAndSettle();
    expect(controller.calls, contains('delete:7'));
  });

  testWidgets('routed card mounts a RoutePreview and navigates to start',
      (tester) async {
    final launcher = FakeNavigationLauncher();
    await pump(tester, [_routedEntry(5)],
        navLauncher: launcher,
        trackpoints: {
          5: [_tp(5, 52.0, 13.0), _tp(5, 52.01, 13.0)],
        });

    final preview = tester.widget<RoutePreview>(find.byType(RoutePreview));
    expect(preview.rideId, 5);
    expect(preview.hasRoute, isTrue);

    // The preview slot is pinned to the render aspect so BoxFit.cover shows the
    // whole route (no top/bottom crop). Same constant the renderer uses.
    expect(
      find.byWidgetPredicate(
          (w) => w is AspectRatio && w.aspectRatio == previewAspectRatio),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.directions));
    await tester.pump();
    expect(launcher.launches, isNotEmpty);
    // Fetched lazily now (issue #21), not carried on the entry itself.
    expect(launcher.launches.first.$1, 52.0); // start latitude
  });

  testWidgets('tapping a card opens the detail dialog', (tester) async {
    await pump(tester, [_entry(1, desc: 'Morning roll')]);
    await tester.tap(find.text('Morning roll'));
    await tester.pumpAndSettle();
    expect(find.text('Distance'), findsOneWidget);
    expect(find.text('Avg speed'), findsOneWidget);
  });

  testWidgets('favorite heart toggles via the controller', (tester) async {
    await pump(tester, [_entry(3, desc: 'Morning roll')]);
    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pump();
    expect(controller.calls, contains('fav:3'));
  });

  testWidgets('jump-to-ride highlights the target card and clears the target',
      (tester) async {
    await pump(tester, [_entry(1, desc: 'A'), _entry(2, desc: 'B')]);
    container.read(historyTargetRideProvider.notifier).state = 2;
    await tester.pump();
    await tester.pump();

    expect(container.read(historyTargetRideProvider), isNull);
    final target = tester
        .widgetList<HistoryRideCard>(find.byType(HistoryRideCard))
        .firstWhere((c) => c.entry.ride.rideId == 2);
    expect(target.highlighted, isTrue);
    await tester.pump(const Duration(seconds: 2)); // drain the highlight timer
  });

  testWidgets('honours a jump target parked before the screen mounts',
      (tester) async {
    // Home sets the target, then the PageView lazily builds History — so the
    // target is already non-null on first mount and the change-only ref.listen
    // would miss it. The card must still highlight.
    await pump(tester, [_entry(1, desc: 'A'), _entry(2, desc: 'B')],
        presetTarget: 2);
    await tester.pump();
    await tester.pump();

    expect(container.read(historyTargetRideProvider), isNull);
    final target = tester
        .widgetList<HistoryRideCard>(find.byType(HistoryRideCard))
        .firstWhere((c) => c.entry.ride.rideId == 2);
    expect(target.highlighted, isTrue);
    await tester.pump(const Duration(seconds: 2)); // drain the highlight timer
  });

  testWidgets(
      'jumps to a target far DOWN the list — beyond the built window, where '
      'ensureVisible alone cannot reach (the "jump sometimes does nothing" bug)',
      (tester) async {
    // 25 cards ≈ 5750px of list in a 900px viewport: the last ride is far
    // outside viewport + cacheExtent, so its card is not built at mount.
    final items = [for (var i = 1; i <= 25; i++) _entry(i, desc: 'Ride $i')];
    await pump(tester, items, presetTarget: 25);
    await tester.pump(); // initState post-frame → estimate jump
    await tester.pump(); // card built → ensureVisible fine-tune
    await tester.pump(); // settle

    expect(container.read(historyTargetRideProvider), isNull); // consumed
    // The list actually scrolled…
    final scrollable =
        tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(scrollable.position.pixels, greaterThan(0));
    // …and the target card is built + highlighted + on screen.
    final target = tester
        .widgetList<HistoryRideCard>(find.byType(HistoryRideCard))
        .firstWhere((c) => c.entry.ride.rideId == 25);
    expect(target.highlighted, isTrue);
    expect(find.text('Ride 25'), findsOneWidget);
    final rect = tester.getRect(find.text('Ride 25'));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(900));
    await tester.pump(const Duration(seconds: 2)); // drain the highlight timer
  });
}
