import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_colors.dart';
import 'package:retrail/domain/route_markers.dart';
import 'package:retrail/map/route_marker_painter.dart';

const _colors = AppColors.light;

/// Paints [style]'s decorations for a straight 100 px route (20,20)→(120,20)
/// onto a transparent 140×40 canvas and returns its RGBA bytes.
Future<ByteData> _render(RouteEndpointStyle style) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  paintRouteDecorations(
      canvas, const [(x: 20, y: 20), (x: 120, y: 20)], style, _colors);
  final image = await recorder.endRecording().toImage(140, 40);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return bytes!;
}

ui.Color _pixel(ByteData rgba, int x, int y) {
  final i = (y * 140 + x) * 4;
  return ui.Color.fromARGB(rgba.getUint8(i + 3), rgba.getUint8(i),
      rgba.getUint8(i + 1), rgba.getUint8(i + 2));
}

bool _close(ui.Color a, ui.Color b) =>
    (a.r - b.r).abs() < 0.05 &&
    (a.g - b.g).abs() < 0.05 &&
    (a.b - b.b).abs() < 0.05 &&
    (a.a - b.a).abs() < 0.05;

void main() {
  test('open route: hollow green start ring, chequered finish flag', () async {
    final rgba = await _render(RouteEndpointStyle.open);
    // Start: white hole in the centre, green ring around it.
    expect(_close(_pixel(rgba, 20, 20), _colors.onMap), isTrue);
    expect(_close(_pixel(rgba, 24, 20), _colors.markerStartGreen), isTrue);
    // Finish: the chequer has both dark and light squares.
    final finish = [
      for (var dx = -4; dx <= 4; dx++) _pixel(rgba, 120 + dx, 18),
    ];
    expect(finish.any((c) => _close(c, _colors.scrim)), isTrue);
    expect(finish.any((c) => _close(c, _colors.onMap)), isTrue);
  });

  test('loop: one combined marker at the start, none at the end', () async {
    final rgba = await _render(RouteEndpointStyle.loop);
    expect(_close(_pixel(rgba, 26, 20), _colors.markerStartGreen), isTrue);
    expect(_pixel(rgba, 120, 20).a, 0); // nothing drawn at the far end
  });

  test('start only: just the ring, no finish flag', () async {
    final rgba = await _render(RouteEndpointStyle.startOnly);
    expect(_close(_pixel(rgba, 24, 20), _colors.markerStartGreen), isTrue);
    expect(_pixel(rgba, 120, 20).a, 0);
  });

  test('draws a direction chevron one spacing along the line', () async {
    final rgba = await _render(RouteEndpointStyle.none);
    final x = 20 + routeArrowSpacing.toInt();
    final around = [
      for (var dx = -3; dx <= 3; dx++)
        for (var dy = -3; dy <= 3; dy++) _pixel(rgba, x + dx, 20 + dy),
    ];
    expect(around.any((c) => c.a > 0.5), isTrue);
    // …and nothing where no arrow belongs (inside the start margin).
    expect(_pixel(rgba, 30, 20).a, 0);
  });

  test('marker and arrow PNGs rasterise at the requested pixel ratio',
      () async {
    for (final kind in RouteMarkerImage.values) {
      final png = await routeMarkerImagePng(kind, _colors, 3);
      final codec = await ui.instantiateImageCodec(png);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, greaterThanOrEqualTo(45), reason: '$kind');
      expect(frame.image.width, frame.image.height);
    }
    final arrow = await routeArrowImagePng(_colors, 3);
    expect(arrow, isNotEmpty);
  });
}
