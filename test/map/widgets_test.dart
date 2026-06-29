import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_colors.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/map/live_map.dart';
import 'package:retrail/map/preview_projection.dart';
import 'package:retrail/map/route_preview.dart';
import 'package:retrail/map/route_preview_cache.dart';
import 'package:retrail/map/route_sketch.dart';

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(theme: buildTheme(brightness), home: Scaffold(body: child));

/// Records the brightness the widget requests, without real file IO (which
/// never settles under `testWidgets`).
class _RecordingCache extends RoutePreviewCache {
  _RecordingCache()
      : super(
            baseDir: Directory.systemTemp,
            render: (_, _) async => Uint8List(0));
  Brightness? requested;
  @override
  Future<File> ensurePreview(int rideId, List<RoutePoint> points,
      {required Brightness brightness}) async {
    requested = brightness;
    return File('${Directory.systemTemp.path}/never_read.png');
  }
}

void main() {
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
            points: const [(lat: 1, lng: 2), (lat: 3, lng: 4)],
            cache: cache),
      ),
    ));
    expect(cache.requested, Brightness.dark); // dark theme → dark snapshot
  });

  testWidgets('RoutePreview with no route shows the sketch fallback',
      (tester) async {
    final cache = RoutePreviewCache(
      baseDir: Directory.systemTemp,
      render: (_, _) async => Uint8List(0),
    );
    await tester.pumpWidget(_wrap(
      SizedBox(
        width: 200,
        height: 100,
        child: RoutePreview(rideId: 1, points: const [], cache: cache),
      ),
    ));
    expect(find.byType(RouteSketch), findsOneWidget);
  });

  testWidgets('LiveMap builds with a route', (tester) async {
    const route = <RoutePoint>[
      (lat: 49.44, lng: 11.08),
      (lat: 49.45, lng: 11.10),
    ];
    await tester.pumpWidget(_wrap(
      const SizedBox(width: 300, height: 300, child: LiveMap(points: route)),
    ));
    expect(find.byType(FlutterMap), findsOneWidget);
  });

  testWidgets('LiveMap fills gaps with terrain (not grey) and caches tiles',
      (tester) async {
    const route = <RoutePoint>[
      (lat: 49.44, lng: 11.08),
      (lat: 49.45, lng: 11.10),
    ];
    await tester.pumpWidget(_wrap(
      const SizedBox(width: 300, height: 300, child: LiveMap(points: route)),
    ));

    // Un-loaded area shows the map's terrain colour, not flutter_map's grey.
    final options = tester.widget<FlutterMap>(find.byType(FlutterMap)).options;
    expect(options.backgroundColor, AppColors.light.mapTerrain);

    final tiles = tester.widget<TileLayer>(find.byType(TileLayer));
    expect(tiles.panBuffer, 2); // preload a ring so zoom-out reveals loaded tiles
    final provider = tiles.tileProvider;
    expect(provider, isA<NetworkTileProvider>());
    // Disk caching on → revisited tiles are served locally (faster, no refetch).
    expect((provider as NetworkTileProvider).cachingProvider, isNotNull);
  });

  testWidgets('LiveMap constrains zoom so you cannot pinch out indefinitely',
      (tester) async {
    const route = <RoutePoint>[
      (lat: 49.44, lng: 11.08),
      (lat: 49.45, lng: 11.10),
    ];
    await tester.pumpWidget(_wrap(
      const SizedBox(width: 300, height: 300, child: LiveMap(points: route)),
    ));
    final options = tester.widget<FlutterMap>(find.byType(FlutterMap)).options;
    expect(options.minZoom, kLiveMapMinZoom); // floor → no world-speck zoom-out
    expect(options.maxZoom, kLiveMapMaxZoom);
  });
}
