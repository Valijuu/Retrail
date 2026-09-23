import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/map/live_map.dart';
import 'package:retrail/map/preview_projection.dart';
import 'package:retrail/map/preview_snapshot.dart' show PreviewResult;
import 'package:retrail/map/route_preview.dart';
import 'package:retrail/map/route_preview_cache.dart';
import 'package:retrail/map/route_sketch.dart';

import '../support/live_map_stub.dart';

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(theme: buildTheme(brightness), home: Scaffold(body: child));

/// Records the brightness the widget requests, without real file IO (which
/// never settles under `testWidgets`).
class _RecordingCache extends RoutePreviewCache {
  _RecordingCache()
      : super(
            baseDir: Directory.systemTemp,
            render: (_, _) async =>
                PreviewResult(Uint8List(0), complete: true));
  Brightness? requested;
  @override
  Future<File> ensurePreview(int rideId, List<RoutePoint> points,
      {required Brightness brightness}) async {
    requested = brightness;
    return File('${Directory.systemTemp.path}/never_read.png');
  }
}

/// A cache whose preview is already resolved (as after ride-save / first view),
/// without real file IO — which never settles under `testWidgets`.
class _WarmCache extends RoutePreviewCache {
  _WarmCache()
      : super(
            baseDir: Directory.systemTemp,
            render: (_, _) async =>
                PreviewResult(Uint8List(0), complete: true));

  @override
  File? resolvedFileFor(int rideId, {required Brightness brightness}) =>
      File('${Directory.systemTemp.path}/warm_$rideId.png');
}

/// A cache whose preview starts stale (unresolved) and can be flipped to
/// resolved + announced as upgraded, without real file IO.
class _UpgradingCache extends RoutePreviewCache {
  _UpgradingCache()
      : super(
            baseDir: Directory.systemTemp,
            render: (_, _) async =>
                PreviewResult(Uint8List(0), complete: true));

  final _upgradeEvents = StreamController<int>.broadcast();
  bool resolved = false;

  @override
  Stream<int> get upgrades => _upgradeEvents.stream;

  @override
  File? resolvedFileFor(int rideId, {required Brightness brightness}) =>
      resolved ? File('${Directory.systemTemp.path}/up_$rideId.png') : null;

  @override
  Future<File> ensurePreview(int rideId, List<RoutePoint> points,
          {required Brightness brightness}) async =>
      File('${Directory.systemTemp.path}/up_$rideId.png');

  void upgrade(int rideId) {
    resolved = true;
    _upgradeEvents.add(rideId);
  }
}

void main() {
  useStubLiveMap();

  testWidgets('RoutePreview requests the variant matching the current theme',
      (tester) async {
    final cache = _RecordingCache();
    await tester.pumpWidget(_wrap(
      brightness: Brightness.dark,
      SizedBox(
        width: 200,
        height: 100,
        child: RoutePreview(
            rideId: 1,
            hasRoute: true,
            pointsLoader: () async => const [(lat: 1, lng: 2), (lat: 3, lng: 4)],
            cache: cache),
      ),
    ));
    await tester.pump();
    expect(cache.requested, Brightness.dark); // dark theme → dark snapshot
  });

  testWidgets('RoutePreview with no route shows the sketch fallback',
      (tester) async {
    final cache = RoutePreviewCache(
      baseDir: Directory.systemTemp,
      render: (_, _) async => PreviewResult(Uint8List(0), complete: true),
    );
    await tester.pumpWidget(_wrap(
      SizedBox(
        width: 200,
        height: 100,
        child: RoutePreview(
            rideId: 1,
            hasRoute: false,
            pointsLoader: () async => const [],
            cache: cache),
      ),
    ));
    expect(find.byType(RouteSketch), findsOneWidget);
  });

  testWidgets(
      'RoutePreview shows the image on the FIRST frame once the cache has '
      'resolved it (no sketch flash, no points fetch, while scrolling)',
      (tester) async {
    final cache = _WarmCache();
    var loaderCalls = 0;

    await tester.pumpWidget(_wrap(
      SizedBox(
        width: 200,
        height: 100,
        child: RoutePreview(
          rideId: 1,
          hasRoute: true,
          pointsLoader: () async {
            loaderCalls++;
            return const [(lat: 1, lng: 2), (lat: 3, lng: 4)];
          },
          cache: cache,
        ),
      ),
    ));
    // First build, no pump: the sync fast path must already show the image —
    // no RouteSketch flash, no FutureBuilder round-trip, no points fetch.
    expect(find.byType(RouteSketch), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    expect(loaderCalls, 0);
  });

  testWidgets('LiveMap builds (native map stubbed via static override)',
      (tester) async {
    const route = <RoutePoint>[
      (lat: 49.44, lng: 11.08),
      (lat: 49.45, lng: 11.10),
    ];
    await tester.pumpWidget(_wrap(
      const SizedBox(width: 300, height: 300, child: LiveMap(points: route)),
    ));
    expect(find.byKey(const ValueKey('stub-map')), findsOneWidget);
  });

  // The zoom envelope is now a native MapOptions concern; assert the consts the
  // map is built from directly (no rendered map needed).
  test('live map zoom envelope', () {
    expect(kLiveMapMinZoom, 3.0);
    expect(kLiveMapMaxZoom, 19.0);
  });

  testWidgets(
      'RoutePreview re-resolves when the cache announces an upgrade of its '
      'ride (stale offline sketch → real map, issue #31)', (tester) async {
    final cache = _UpgradingCache();
    await tester.pumpWidget(_wrap(
      SizedBox(
        width: 200,
        height: 100,
        child: RoutePreview(
          rideId: 1,
          hasRoute: true,
          pointsLoader: () async => const [(lat: 1, lng: 2), (lat: 3, lng: 4)],
          cache: cache,
        ),
      ),
    ));
    expect(find.byType(FutureBuilder<File>), findsOneWidget); // not resolved

    cache.upgrade(2); // another ride — ignored
    await tester.pump();
    expect(find.byType(FutureBuilder<File>), findsOneWidget);

    cache.upgrade(1);
    await tester.pump(); // deliver the broadcast event
    await tester.pump(); // rebuild after the listener's setState
    expect(find.byType(FutureBuilder<File>), findsNothing); // sync fast path
    expect(find.byType(Image), findsOneWidget);
  });
}
