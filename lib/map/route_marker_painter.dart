import 'dart:typed_data';
import 'dart:ui' as ui;

import '../core/theme/app_colors.dart';
import '../domain/route_markers.dart';
import 'preview_projection.dart';

/// Canvas drawing for a route's endpoint markers and direction arrows, shared
/// by the tiled preview PNG, the offline sketch PNG and the [RouteSketch]
/// widget (the MapLibre map rasterises the same markers via
/// [routeMarkerImagePng] / [routeArrowImagePng]). All sizes are logical px
/// (dp); callers scale the canvas for their pixel ratio.
///
/// - Start: a hollow ring (white centre, green border).
/// - Finish: a small chequered flag disc.
/// - Loop (start and finish together, see [routeEndpointStyle]): the
///   chequered disc inside the green start ring — one marker, not two
///   stacked on top of each other.
/// - Arrows: blue arrowheads with a white rim on the line, pointing the way
///   it was ridden.

/// Room to leave between a route and the edge of a box it is fitted into, so
/// the largest endpoint marker (the loop marker's halo) is never clipped.
const double routeMarkerInset = _loopHaloRadius + 1;

/// Distance between direction arrows along the drawn line.
const double routeArrowSpacing = 44;

/// Keeps arrows clear of the start/finish markers.
const double _arrowEndMargin = 12;

/// Half the arrowhead's width across the line, its length along it, and its
/// white rim: about twice the 3.5dp line's width, in the line's own blue with
/// the line's white halo, so it reads as the route's own arrowhead — clearly
/// visible at card size without looking pasted on. (Heads inside the line,
/// or white ones on it, were too faint or read as gaps.)
const double _arrowHalfWidth = 3.6;
const double _arrowLength = 6;
const double _arrowRim = 1.6;

const double _haloRadius = 7.5;
const double _ringRadius = 6;
const double _ringHoleRadius = 3;
const double _flagRadius = 6;
const double _loopHaloRadius = 9;
const double _loopRingRadius = 7.5;
const double _loopFlagRadius = 5;

/// Squares per side of the chequered finish pattern.
const int _checks = 4;

/// Paints the direction arrows along [offsets], then the endpoint markers for
/// [style] on top. Call after the route line has been drawn.
void paintRouteDecorations(
  ui.Canvas canvas,
  List<PreviewOffset> offsets,
  RouteEndpointStyle style,
  AppColors colors,
) {
  paintRouteArrows(canvas, offsets, colors);
  if (offsets.isEmpty) return;
  final start = ui.Offset(offsets.first.x, offsets.first.y);
  final end = ui.Offset(offsets.last.x, offsets.last.y);
  switch (style) {
    case RouteEndpointStyle.none:
      break;
    case RouteEndpointStyle.startOnly:
      paintStartRing(canvas, start, colors);
    case RouteEndpointStyle.open:
      paintStartRing(canvas, start, colors);
      paintFinishFlag(canvas, end, colors);
    case RouteEndpointStyle.loop:
      paintLoopMarker(canvas, start, colors);
  }
}

/// Grey arrowheads along [offsets] (see [directionArrows]).
void paintRouteArrows(
  ui.Canvas canvas,
  List<PreviewOffset> offsets,
  AppColors colors,
) {
  for (final a in directionArrows(
    offsets,
    spacing: routeArrowSpacing,
    endMargin: _arrowEndMargin,
  )) {
    canvas.save();
    canvas.translate(a.x, a.y);
    canvas.rotate(a.angle);
    _paintArrowhead(canvas, colors);
    canvas.restore();
  }
}

/// One arrowhead (`▶`) centred on the origin, pointing along +x: a white rim
/// (like the line's halo) around a [AppColors.routeLineBlue] fill.
void _paintArrowhead(ui.Canvas canvas, AppColors colors) {
  final head = ui.Path()
    ..moveTo(_arrowLength / 2, 0)
    ..lineTo(-_arrowLength / 2, -_arrowHalfWidth)
    ..lineTo(-_arrowLength / 2, _arrowHalfWidth)
    ..close();
  canvas.drawPath(
      head,
      ui.Paint()
        ..color = colors.routeLineHalo
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = _arrowRim
        ..strokeJoin = ui.StrokeJoin.round);
  canvas.drawPath(head, ui.Paint()..color = colors.routeLineBlue);
}

/// Hollow start ring: white halo, green ring, white hole.
void paintStartRing(ui.Canvas canvas, ui.Offset c, AppColors colors) {
  canvas.drawCircle(c, _haloRadius, ui.Paint()..color = colors.onMap);
  canvas.drawCircle(
    c,
    _ringRadius,
    ui.Paint()..color = colors.markerStartGreen,
  );
  canvas.drawCircle(c, _ringHoleRadius, ui.Paint()..color = colors.onMap);
}

/// Chequered finish-flag disc on a white halo.
void paintFinishFlag(ui.Canvas canvas, ui.Offset c, AppColors colors) {
  canvas.drawCircle(c, _haloRadius, ui.Paint()..color = colors.onMap);
  _paintChequer(canvas, c, _flagRadius, colors);
}

/// Start and finish in one: the chequered disc inside the green start ring.
void paintLoopMarker(ui.Canvas canvas, ui.Offset c, AppColors colors) {
  canvas.drawCircle(c, _loopHaloRadius, ui.Paint()..color = colors.onMap);
  canvas.drawCircle(
    c,
    _loopRingRadius,
    ui.Paint()..color = colors.markerStartGreen,
  );
  canvas.drawCircle(c, _loopFlagRadius + 1, ui.Paint()..color = colors.onMap);
  _paintChequer(canvas, c, _loopFlagRadius, colors);
}

void _paintChequer(
  ui.Canvas canvas,
  ui.Offset c,
  double radius,
  AppColors colors,
) {
  final box = ui.Rect.fromCircle(center: c, radius: radius);
  final cell = box.width / _checks;
  canvas.save();
  canvas.clipPath(ui.Path()..addOval(box));
  canvas.drawRect(box, ui.Paint()..color = colors.onMap);
  final dark = ui.Paint()..color = colors.scrim;
  for (var row = 0; row < _checks; row++) {
    for (var col = 0; col < _checks; col++) {
      if ((row + col).isOdd) continue;
      canvas.drawRect(
        ui.Rect.fromLTWH(
          box.left + col * cell,
          box.top + row * cell,
          cell,
          cell,
        ),
        dark,
      );
    }
  }
  canvas.restore();
}

/// Which marker a MapLibre symbol image shows.
enum RouteMarkerImage { start, finish, loop }

/// [kind] rasterised to a PNG for a MapLibre symbol layer, at [pixelRatio]
/// (the map scales icons by its own device pixel ratio, so pass the screen's).
Future<Uint8List> routeMarkerImagePng(
  RouteMarkerImage kind,
  AppColors colors,
  double pixelRatio,
) {
  final radius = kind == RouteMarkerImage.loop ? _loopHaloRadius : _haloRadius;
  return _rasterise(radius * 2, pixelRatio, (canvas, c) {
    switch (kind) {
      case RouteMarkerImage.start:
        paintStartRing(canvas, c, colors);
      case RouteMarkerImage.finish:
        paintFinishFlag(canvas, c, colors);
      case RouteMarkerImage.loop:
        paintLoopMarker(canvas, c, colors);
    }
  });
}

/// A single arrowhead pointing along +x (east) as a PNG, for MapLibre's
/// line-placed arrow symbols (the map rotates it along the line).
Future<Uint8List> routeArrowImagePng(AppColors colors, double pixelRatio) =>
    _rasterise(
      2 * _arrowHalfWidth + _arrowRim,
      pixelRatio,
      (canvas, c) {
        canvas.translate(c.dx, c.dy);
        _paintArrowhead(canvas, colors);
      },
    );

Future<Uint8List> _rasterise(
  double sizeDp,
  double pixelRatio,
  void Function(ui.Canvas canvas, ui.Offset centre) draw,
) async {
  final px = (sizeDp * pixelRatio).ceil();
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)..scale(pixelRatio);
  draw(canvas, ui.Offset(sizeDp / 2, sizeDp / 2));
  final picture = recorder.endRecording();
  final image = await picture.toImage(px, px);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  return bytes!.buffer.asUint8List();
}
