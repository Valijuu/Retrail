import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/map/live_map.dart';
import 'package:retrail/map/preview_projection.dart';
import 'package:retrail/map/route_preview.dart';
import 'package:retrail/map/route_preview_cache.dart';
import 'package:retrail/map/route_sketch.dart';

Widget _wrap(Widget child) =>
    MaterialApp(theme: buildTheme(Brightness.light), home: Scaffold(body: child));

void main() {
  testWidgets('RoutePreview with no route shows the sketch fallback',
      (tester) async {
    final cache = RoutePreviewCache(
      baseDir: Directory.systemTemp,
      render: (_) async => Uint8List(0),
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
}
