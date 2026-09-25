import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../domain/route_markers.dart';
import 'preview_projection.dart';
import 'route_marker_painter.dart';
import '../core/theme/theme_context.dart';

/// Proportionally scales [points] into a [w] × [h] box, centered. Tile-free
/// fallback geometry (offline preview / no route data). Y is inverted so north
/// is up. Mirrors the original `RouteSketch` scaling. [inset] keeps the
/// route that far from every edge, so endpoint markers drawn on it aren't
/// clipped by the box.
List<PreviewOffset> sketchOffsets(List<RoutePoint> points, double boxW,
    double boxH, {double inset = 0}) {
  if (points.isEmpty) return const [];
  final w = boxW - 2 * inset;
  final h = boxH - 2 * inset;
  final lats = points.map((p) => p.lat);
  final lngs = points.map((p) => p.lng);
  final minLat = lats.reduce(math.min);
  final maxLat = lats.reduce(math.max);
  final minLng = lngs.reduce(math.min);
  final maxLng = lngs.reduce(math.max);
  // The floor only bounds the SCALE for a degenerate extent (a single point,
  // a due N–S / E–W line); centring uses the real extent, otherwise such a
  // route was pinned to the box's top/left edge (issue #31).
  final scale = math.min(w / math.max(maxLng - minLng, 0.0001),
      h / math.max(maxLat - minLat, 0.0001));
  final padX = inset + (w - (maxLng - minLng) * scale) / 2;
  final padY = inset + (h - (maxLat - minLat) * scale) / 2;
  return [
    for (final p in points)
      (x: padX + (p.lng - minLng) * scale, y: padY + (maxLat - p.lat) * scale),
  ];
}

/// Pure-canvas route preview over a flat [AppColors.mapTerrain] background — no
/// tiles, no network. Used as the offline preview fallback and the live-map
/// empty state.
class RouteSketch extends StatelessWidget {
  const RouteSketch({super.key, required this.points});

  final List<RoutePoint> points;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CustomPaint(painter: _RouteSketchPainter(points, colors), size: Size.infinite);
  }
}

class _RouteSketchPainter extends CustomPainter {
  _RouteSketchPainter(this.points, this.colors);

  final List<RoutePoint> points;
  final AppColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = colors.mapTerrain);
    if (points.length < 2) return;
    final offsets = sketchOffsets(points, size.width, size.height,
        inset: routeMarkerInset);
    final path = Path()..moveTo(offsets.first.x, offsets.first.y);
    for (final o in offsets.skip(1)) {
      path.lineTo(o.x, o.y);
    }
    canvas.drawPath(path, _stroke(colors.routeLineHalo, 6));
    canvas.drawPath(path, _stroke(colors.routeLineBlue, 3.5));
    paintRouteDecorations(canvas, offsets, routeEndpointStyle(points), colors);
  }

  Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  bool shouldRepaint(_RouteSketchPainter old) =>
      old.points != points || old.colors != colors;
}
