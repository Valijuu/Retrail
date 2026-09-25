import 'dart:typed_data';
import 'dart:ui' as ui;

import '../core/theme/app_colors.dart';
import '../domain/route_markers.dart';
import 'preview_projection.dart';
import 'route_marker_painter.dart';
import 'route_sketch.dart' show sketchOffsets;
import 'tile_grid.dart';

/// Supplies decoded raster tiles for the snapshot renderer. Injectable so tests
/// use deterministic fake tiles (no network).
abstract interface class PreviewTileProvider {
  Future<ui.Image?> tile(int z, int x, int y, ui.Brightness brightness);
}

/// A rendered preview PNG plus whether it is the final quality. [complete] is
/// false for a degraded fallback — the offline sketch, or a snapshot with one
/// or more failed tiles — telling the cache to serve it now but mark it stale
/// and regenerate it opportunistically instead of baking the hole in forever.
class PreviewResult {
  const PreviewResult(this.bytes, {required this.complete});

  final Uint8List bytes;
  final bool complete;
}

/// Renders a route preview **once** into a PNG: composites basemap tiles, draws
/// the halo + blue polyline and start/end dots, and exports. Designed to run at
/// ride-save and be cached to disk — history/home then just show the image.
Future<PreviewResult> renderPreviewPng({
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
  // Any failed tile leaves a terrain-colored hole — usable right now, but the
  // result must not be cached as final (see [PreviewResult.complete]).
  var missingTile = false;
  for (var i = 0; i < grid.length; i++) {
    final image = images[i];
    if (image == null) {
      missingTile = true;
      continue;
    }
    final t = grid[i];
    final src = ui.Rect.fromLTWH(
        0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = ui.Rect.fromLTWH(
        t.offsetXDp, t.offsetYDp, tileSize.toDouble(), tileSize.toDouble());
    canvas.drawImageRect(
        image, src, dst, ui.Paint()..filterQuality = ui.FilterQuality.medium);
    image.dispose();
  }

  final offsets = [for (final p in points) projectPoint(p, framing)];
  _paintRoute(canvas, offsets, colors);
  // Arrows + start ring / finish flag (or the combined loop marker), matching
  // the live detail map; a single-point ride still shows its start ring.
  paintRouteDecorations(canvas, offsets, routeEndpointStyle(points), colors);

  final picture = recorder.endRecording();
  final image = await picture.toImage(
      (widthDp * pixelRatio).round(), (heightDp * pixelRatio).round());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  return PreviewResult(bytes!.buffer.asUint8List(), complete: !missingTile);
}

/// Halo + blue route line through [offsets] (nothing for fewer than two).
void _paintRoute(
    ui.Canvas canvas, List<PreviewOffset> offsets, AppColors colors) {
  if (offsets.length < 2) return;
  final path = ui.Path()..moveTo(offsets.first.x, offsets.first.y);
  for (final o in offsets.skip(1)) {
    path.lineTo(o.x, o.y);
  }
  canvas.drawPath(path, _stroke(colors.routeLineHalo, 6));
  canvas.drawPath(path, _stroke(colors.routeLineBlue, 3.5));
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
/// generation time (Spec 12 wiring); always `complete: false` so the cache
/// marks it stale and regenerates the full-tile snapshot when back online.
Future<PreviewResult> renderSketchPng({
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

  final offsets = sketchOffsets(points, w, h, inset: routeMarkerInset);
  _paintRoute(canvas, offsets, colors);
  paintRouteDecorations(canvas, offsets, routeEndpointStyle(points), colors);

  final picture = recorder.endRecording();
  final image = await picture.toImage(
      (widthDp * pixelRatio).round(), (heightDp * pixelRatio).round());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  return PreviewResult(bytes!.buffer.asUint8List(), complete: false);
}
