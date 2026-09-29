import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../domain/route_markers.dart';
import 'preview_projection.dart';
import 'route_camera.dart';
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
/// tiles, no network. Used as the offline preview fallback, the live-map
/// empty state and the ride detail map's loading / offline placeholder.
class RouteSketch extends StatelessWidget {
  const RouteSketch({super.key, required this.points, this.camera});

  final List<RoutePoint> points;

  /// When set, the route is projected as a MapLibre map at this camera shows
  /// it ([cameraOffsets]) and drawn at the map's line widths, so the sketch
  /// lines up with the map it cross-fades into. Null → the proportional fit.
  final RouteCamera? camera;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CustomPaint(
        painter: _RouteSketchPainter(points, colors, camera),
        size: Size.infinite);
  }
}

/// The live map's route line widths (halo, line) — see live_map.dart.
const double _mapHaloWidth = 8.0;
const double _mapLineWidth = 4.5;

class _RouteSketchPainter extends CustomPainter {
  _RouteSketchPainter(this.points, this.colors, this.camera);

  final List<RoutePoint> points;
  final AppColors colors;
  final RouteCamera? camera;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = colors.mapTerrain);
    final cam = camera;
    // Like the map, the camera sketch marks even a single-point ride's start
    // (issue #44); the plain sketch needs a line to draw anything.
    if (points.isEmpty || (points.length < 2 && cam == null)) return;
    final offsets = cam != null
        ? cameraOffsets(points, cam, width: size.width, height: size.height)
        : sketchOffsets(points, size.width, size.height,
            inset: routeMarkerInset);
    if (offsets.length >= 2) {
      final path = Path()..moveTo(offsets.first.x, offsets.first.y);
      for (final o in offsets.skip(1)) {
        path.lineTo(o.x, o.y);
      }
      canvas.drawPath(path,
          _stroke(colors.routeLineHalo, cam != null ? _mapHaloWidth : 6));
      canvas.drawPath(path,
          _stroke(colors.routeLineBlue, cam != null ? _mapLineWidth : 3.5));
    }
    // With a camera the sketch stands in for the map: its markers at the map's
    // size, and no arrows — MapLibre places its own along the line, which a
    // canvas can't match, so a second set would show through the fade.
    paintRouteDecorations(canvas, offsets, routeEndpointStyle(points), colors,
        arrows: cam == null,
        markerScale: cam != null ? mapEndpointMarkerScale : 1);
  }

  Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  bool shouldRepaint(_RouteSketchPainter old) =>
      old.points != points || old.colors != colors || old.camera != camera;
}
