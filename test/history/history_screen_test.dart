import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/db/ride_dao.dart';
import 'package:retrail/data/db/ride_with_trackpoints.dart';
import 'package:retrail/data/repositories/ride_repository.dart';
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

class FakeNavigationLauncher implements NavigationLauncher {
  final launches = <(double, double, String)>[];
  @override
  Future<void> launchTo(double lat, double lng, String label) async =>
      launches.add((lat, lng, label));
}

RideEntryItem _routedEntry(int id) => RideEntryItem(
      RideWithTrackpoints(
        ride: _ride(id, desc: 'Routed ride'),
        trackpoints: [
          Trackpoint(
              trackpointId: 0,
              rideId: id,
              latitude: 52.0,
              longitude: 13.0,
              timestamp: 0),
          Trackpoint(
              trackpointId: 1,
              rideId: id,
              latitude: 52.01,
              longitude: 13.0,
              timestamp: 1),
        ],
      ),
      const RideStats(
          durationMs: 600000, distanceMetres: 1200, maxSpeedKmh: 22, avgSpeedKmh: 15),
    );

Ride _ride(int id, {String? desc, String? typ, bool fav = false}) => Ride(
      rideId: id,
      description: desc,
      typ: typ,
      startTime: 0,
      endTime: 600000, // 10 min
      date: 1718193600000,
      comment: null,
      isFavorite: fav,
      favoritedAt: null,
    );

RideEntryItem _entry(int id, {String? desc, String? typ, bool fav = false}) =>
    RideEntryItem(
      RideWithTrackpoints(ride: _ride(id, desc: desc, typ: typ, fav: fav), trackpoints: const []),
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
          baseDir: Directory.systemTemp, render: (_, _) async => Uint8List(0)),
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
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    container = ProviderContainer(overrides: [
      previewCacheDirProvider.overrideWithValue(Directory.systemTemp),
      historyItemsProvider.overrideWith((ref) => Stream.value(items)),
      historyControllerProvider.overrideWithValue(controller),
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
    await pump(tester, [_routedEntry(5)], navLauncher: launcher);

    final preview = tester.widget<RoutePreview>(find.byType(RoutePreview));
    expect(preview.rideId, 5);
    expect(preview.points.length, 2);

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
        .firstWhere((c) => c.entry.rwt.ride.rideId == 2);
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
        .firstWhere((c) => c.entry.rwt.ride.rideId == 2);
    expect(target.highlighted, isTrue);
    await tester.pump(const Duration(seconds: 2)); // drain the highlight timer
  });
}
