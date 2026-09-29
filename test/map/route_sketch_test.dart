import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_colors.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/map/preview_projection.dart';
import 'package:retrail/map/route_sketch.dart';

const _w = 400, _h = 300;

/// Pumps [sketch] into a [_w] × [_h] box and returns its RGBA pixels.
Future<ByteData> _renderSketch(WidgetTester tester, RouteSketch sketch) async {
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    theme: buildTheme(Brightness.light),
    home: Center(
      child: RepaintBoundary(
        key: key,
        child: SizedBox(
            width: _w.toDouble(), height: _h.toDouble(), child: sketch),
      ),
    ),
  ));
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return bytes!;
  }))!;
}

ui.Color _pixel(ByteData rgba, int x, int y) {
  final i = (y * _w + x) * 4;
  return ui.Color.fromARGB(rgba.getUint8(i + 3), rgba.getUint8(i),
      rgba.getUint8(i + 1), rgba.getUint8(i + 2));
}

bool _close(ui.Color a, ui.Color b) =>
    (a.r - b.r).abs() < 0.05 &&
    (a.g - b.g).abs() < 0.05 &&
    (a.b - b.b).abs() < 0.05;

void main() {
  group('sketchOffsets', () {
    test('empty input → empty', () {
      expect(sketchOffsets(const [], 100, 50), isEmpty);
    });

    test('all offsets land inside the box', () {
      const points = <RoutePoint>[
        (lat: 49.44, lng: 11.08),
        (lat: 49.45, lng: 11.10),
        (lat: 49.46, lng: 11.12),
      ];
      for (final o in sketchOffsets(points, 200, 100)) {
        expect(o.x, inInclusiveRange(0, 200));
        expect(o.y, inInclusiveRange(0, 100));
      }
    });

    test('inset keeps every offset at least that far from each edge', () {
      const points = <RoutePoint>[
        (lat: 49.40, lng: 11.00),
        (lat: 49.50, lng: 11.20),
        (lat: 49.45, lng: 11.10),
      ];
      for (final o in sketchOffsets(points, 200, 100, inset: 12)) {
        expect(o.x, inClosedOpenRange(12, 188.0001));
        expect(o.y, inClosedOpenRange(12, 88.0001));
      }
      // …and the route still spans the inset box on its limiting axis.
      final ys = sketchOffsets(points, 200, 100, inset: 12).map((o) => o.y);
      expect(ys.reduce((a, b) => a < b ? a : b), closeTo(12, 1e-6));
      expect(ys.reduce((a, b) => a > b ? a : b), closeTo(88, 1e-6));
    });

    test('eastern point is right of western; northern is above southern', () {
      const points = <RoutePoint>[
        (lat: 49.44, lng: 11.08), // SW
        (lat: 49.46, lng: 11.12), // NE
      ];
      final offsets = sketchOffsets(points, 200, 100);
      expect(offsets.last.x, greaterThan(offsets.first.x)); // east → larger x
      expect(offsets.last.y, lessThan(offsets.first.y)); // north → smaller y
    });

    test('a single point sits in the centre, not at the top edge (issue #31)',
        () {
      final o = sketchOffsets(const [(lat: 49.44, lng: 11.08)], 320, 112);
      expect(o.single.x, closeTo(160, 1e-9));
      expect(o.single.y, closeTo(56, 1e-9));
    });

    test('a due north-south line is centred horizontally', () {
      const points = <RoutePoint>[
        (lat: 49.44, lng: 11.08),
        (lat: 49.46, lng: 11.08),
      ];
      for (final o in sketchOffsets(points, 320, 112)) {
        expect(o.x, closeTo(160, 1e-9));
      }
    });
  });

  group('RouteSketch with a camera (detail map placeholder)', () {
    const colors = AppColors.light;
    const camera = (lat: 49.4, lng: 11.0, zoom: 10.0);
    // At z10 this route runs x ≈ 272.8 → 345.6 along y = 150 — right of centre.
    const route = <RoutePoint>[(lat: 49.4, lng: 11.05), (lat: 49.4, lng: 11.1)];

    testWidgets('draws the route where the map at that camera shows it',
        (tester) async {
      final rgba = await _renderSketch(
          tester, const RouteSketch(points: route, camera: camera));
      expect(_close(_pixel(rgba, 310, 150), colors.routeLineBlue), isTrue,
          reason: 'mid-route is the line');
      expect(_close(_pixel(rgba, 100, 150), colors.mapTerrain), isTrue,
          reason: 'left of the camera centre there is no route');
    });

    testWidgets(
        'a single-point ride still shows its start marker, like the map '
        '(issue #44)', (tester) async {
      final rgba = await _renderSketch(tester,
          const RouteSketch(points: [(lat: 49.4, lng: 11.0)], camera: camera));
      // Camera centre → box centre: the start ring's white hole, green ring.
      expect(_close(_pixel(rgba, 200, 150), colors.onMap), isTrue);
      expect(_close(_pixel(rgba, 206, 150), colors.markerStartGreen), isTrue);
    });

    testWidgets('endpoint markers use the map\'s symbol size (×1.3)',
        (tester) async {
      final rgba = await _renderSketch(
          tester, const RouteSketch(points: route, camera: camera));
      // 8.5 px west of the start: outside the 7.5 px halo at ×1, inside the
      // 9.75 px halo at ×1.3.
      expect(_close(_pixel(rgba, 264, 150), colors.onMap), isTrue);
    });
  });
}
