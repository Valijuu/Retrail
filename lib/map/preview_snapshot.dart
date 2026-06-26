import 'dart:typed_data';
import 'dart:ui' as ui;

import '../core/theme/app_colors.dart';
import 'preview_projection.dart';
import 'route_sketch.dart' show sketchOffsets;
import 'tile_grid.dart';

/// Supplies decoded raster tiles for the snapshot renderer. Injectable so tests
/// use deterministic fake tiles (no network).
abstract interface class PreviewTileProvider {
  Future<ui.Image?> tile(int z, int x, int y, ui.Brightness brightness);
}

/// Renders a route preview **once** into a PNG: composites basemap tiles, draws
/// the halo + blue polyline and start/end dots, and exports. Designed to run at
/// ride-save and be cached to disk — history/home then just show the image.
Future<Uint8List> renderPreviewPng({
  required List<RoutePoint> points,
  required int widthDp,
  required int heightDp,
  required double pixelRatio,
  required PreviewTileProvider tiles,
  required ui.Brightness brightness,
}) async {
  final framing = computeFraming(points, widthDp, heightDp);
  final grid = tilesFor(framing);
  final colors = brightness == ui.Brightness.dark ? AppColors.dark : AppColors.light;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.scale(pixelRatio);

  // Terrain background covers any tile that fails to load.
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, widthDp.toDouble(), heightDp.toDouble()),
    ui.Paint()..color = colors.mapTerrain,
  );

  for (final t in grid) {
    final image = await tiles.tile(t.z, t.x, t.y, brightness);
    if (image == null) continue;
    final src = ui.Rect.fromLTWH(
        0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = ui.Rect.fromLTWH(
        t.offsetXDp, t.offsetYDp, tileSize.toDouble(), tileSize.toDouble());
    canvas.drawImageRect(
        image, src, dst, ui.Paint()..filterQuality = ui.FilterQuality.medium);
  }

  if (points.length >= 2) {
    final path = ui.Path();
    for (var i = 0; i < points.length; i++) {
      final o = projectPoint(points[i], framing);
      if (i == 0) {
        path.moveTo(o.x, o.y);
      } else {
        path.lineTo(o.x, o.y);
      }
    }
    canvas.drawPath(path, _stroke(colors.routeLineHalo, 6));
    canvas.drawPath(path, _stroke(colors.routeLineBlue, 3.5));
  }

  if (points.isNotEmpty) {
    final start = projectPoint(points.first, framing);
    final end = projectPoint(points.last, framing);
    canvas.drawCircle(
        ui.Offset(start.x, start.y), 4, ui.Paint()..color = colors.markerStartGreen);
    canvas.drawCircle(
        ui.Offset(end.x, end.y), 4, ui.Paint()..color = colors.markerEndRed);
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(
      (widthDp * pixelRatio).round(), (heightDp * pixelRatio).round());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  return bytes!.buffer.asUint8List();
}

ui.Paint _stroke(ui.Color color, double width) => ui.Paint()
  ..color = color
  ..style = ui.PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = ui.StrokeCap.round
  ..strokeJoin = ui.StrokeJoin.round;

/// Offline preview: renders the flat route sketch (polyline over the
/// [AppColors] terrain colour, no tiles, no network) to a PNG. Mirrors
/// [RouteSketch]'s geometry. Used by the preview cache when offline at
/// generation time (Spec 12 wiring); regenerated to full tiles when back online.
Future<Uint8List> renderSketchPng({
  required List<RoutePoint> points,
  required int widthDp,
  required int heightDp,
  required double pixelRatio,
  required ui.Brightness brightness,
}) async {
  final colors = brightness == ui.Brightness.dark ? AppColors.dark : AppColors.light;
  final w = widthDp.toDouble();
  final h = heightDp.toDouble();

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.scale(pixelRatio);
  canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, w, h), ui.Paint()..color = colors.mapTerrain);

  final offsets = sketchOffsets(points, w, h);
  if (offsets.length >= 2) {
    final path = ui.Path()..moveTo(offsets.first.x, offsets.first.y);
    for (final o in offsets.skip(1)) {
      path.lineTo(o.x, o.y);
    }
    canvas.drawPath(path, _stroke(colors.routeLineHalo, 6));
    canvas.drawPath(path, _stroke(colors.routeLineBlue, 3.5));
  }
  if (offsets.isNotEmpty) {
    canvas.drawCircle(ui.Offset(offsets.first.x, offsets.first.y), 4,
        ui.Paint()..color = colors.markerStartGreen);
    canvas.drawCircle(ui.Offset(offsets.last.x, offsets.last.y), 4,
        ui.Paint()..color = colors.markerEndRed);
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(
      (widthDp * pixelRatio).round(), (heightDp * pixelRatio).round());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  return bytes!.buffer.asUint8List();
}
