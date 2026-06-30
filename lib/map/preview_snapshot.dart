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

  // Fetch the whole grid concurrently — sequential per-tile awaits made the
  // render as slow as the sum of every tile's network round-trip.
  final images = await Future.wait(
    [for (final t in grid) tiles.tile(t.z, t.x, t.y, brightness)],
  );
  for (var i = 0; i < grid.length; i++) {
    final image = images[i];
    if (image == null) continue;
    final t = grid[i];
    final src = ui.Rect.fromLTWH(
        0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = ui.Rect.fromLTWH(
        t.offsetXDp, t.offsetYDp, tileSize.toDouble(), tileSize.toDouble());
    canvas.drawImageRect(
        image, src, dst, ui.Paint()..filterQuality = ui.FilterQuality.medium);
    image.dispose();
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

  // Start/end dots, matching the live detail map: a green start dot whenever
  // there is a point (so a single-point / standstill ride still shows where it
  // was), and a red end dot only once there are two — each styled with a white
  // halo like the live map's markers.
  if (points.isNotEmpty) {
    final start = projectPoint(points.first, framing);
    _styledDot(canvas, ui.Offset(start.x, start.y), colors.markerStartGreen,
        colors.routeLineHalo);
  }
  if (points.length >= 2) {
    final end = projectPoint(points.last, framing);
    _styledDot(canvas, ui.Offset(end.x, end.y), colors.markerEndRed,
        colors.routeLineHalo);
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(
      (widthDp * pixelRatio).round(), (heightDp * pixelRatio).round());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  return bytes!.buffer.asUint8List();
}

/// A start/end dot styled like the live map's markers: a [color] disc on a white
/// [halo] ring.
void _styledDot(ui.Canvas canvas, ui.Offset c, ui.Color color, ui.Color halo) {
  canvas.drawCircle(c, 6.5, ui.Paint()..color = halo);
  canvas.drawCircle(c, 4.5, ui.Paint()..color = color);
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
    _styledDot(canvas, ui.Offset(offsets.first.x, offsets.first.y),
        colors.markerStartGreen, colors.routeLineHalo);
  }
  if (offsets.length >= 2) {
    _styledDot(canvas, ui.Offset(offsets.last.x, offsets.last.y),
        colors.markerEndRed, colors.routeLineHalo);
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(
      (widthDp * pixelRatio).round(), (heightDp * pixelRatio).round());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  return bytes!.buffer.asUint8List();
}
