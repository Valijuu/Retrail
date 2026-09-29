import 'dart:math' as math;

import 'preview_projection.dart';

/// A camera position for a MapLibre map: centre + (fractional) zoom.
///
/// Computed up front by [fitRouteCamera] and applied in a single `moveCamera`,
/// instead of MapLibre's own `controller.fitBounds`: on iOS (maplibre 0.3.6)
/// `fitBounds` only *starts* an animation and returns immediately, so the
/// follow-up zoom-cap `moveCamera` cancelled it and left the camera on the
/// route's end.
typedef RouteCamera = ({double lat, double lng, double zoom});

/// MapLibre's world width at zoom 0, in logical px (512-px world tiles —
/// twice the 256-px raster tile math of [lonXAtZoom] / [latYAtZoom]).
const double _mapLibreWorldSizeAtZoom0Px = 512.0;

/// Degrees of longitude spanning the whole world.
const double _degreesOfLongitude = 360.0;

/// Default inset (logical px) kept free on every side of the fitted route.
const double _defaultFitPaddingPx = 24.0;

/// Smallest fit target (px), so a viewport no bigger than its padding still
/// yields a finite zoom instead of `log(0)`.
const double _minFitTargetPx = 1.0;

double _log2(double x) => math.log(x) / math.ln2;

/// Computes the bounding-box centre + fractional fit zoom that frames [points]
/// in a [width] × [height] MapLibre viewport, keeping [padding] free on every
/// side. Web-Mercator on the latitude axis; the tighter axis wins. Capped at
/// [maxPreviewZoom] — also the zoom for a degenerate box (single point /
/// standstill). Returns `null` for an empty route.
///
/// Used by the read-only ride detail / fullscreen map in place of MapLibre's
/// `fitBounds` — see [RouteCamera] for why.
RouteCamera? fitRouteCamera(
  List<RoutePoint> points, {
  required double width,
  required double height,
  double padding = _defaultFitPaddingPx,
}) {
  if (points.isEmpty) return null;
  final lats = points.map((p) => p.lat);
  final lngs = points.map((p) => p.lng);
  final north = lats.reduce(math.max);
  final south = lats.reduce(math.min);
  final east = lngs.reduce(math.max);
  final west = lngs.reduce(math.min);
  final lonFrac = (east - west) / _degreesOfLongitude;
  final latFrac = latYFrac(south) - latYFrac(north);

  // Zoom at which a [worldFrac] slice of the world spans [viewportPx] minus
  // padding; a zero-span axis doesn't constrain the zoom at all.
  double zoomToFit(double viewportPx, double worldFrac) {
    if (worldFrac == 0) return double.infinity;
    final targetPx = math.max(viewportPx - 2 * padding, _minFitTargetPx);
    return _log2(targetPx / (_mapLibreWorldSizeAtZoom0Px * worldFrac));
  }

  final zoom = math.min(zoomToFit(width, lonFrac), zoomToFit(height, latFrac));
  return (
    lat: (north + south) / 2,
    lng: (east + west) / 2,
    zoom: math.min(zoom, maxPreviewZoom),
  );
}

/// Projects [points] into a [width] × [height] box exactly where a MapLibre
/// map of that size at [camera] draws them: the camera centre lands on the
/// box centre, x grows east, y grows south (Web-Mercator via [latYFrac]), all
/// scaled by MapLibre's 512-px world at `camera.zoom`. Keeps route order.
///
/// Used by the ride detail map's terrain placeholder sketch, so the sketch
/// lines up with the live map it cross-fades into.
List<PreviewOffset> cameraOffsets(
  List<RoutePoint> points,
  RouteCamera camera, {
  required double width,
  required double height,
}) {
  final worldPx =
      _mapLibreWorldSizeAtZoom0Px * math.pow(2, camera.zoom).toDouble();
  return [
    for (final p in points)
      (
        x: width / 2 + worldPx * (p.lng - camera.lng) / _degreesOfLongitude,
        y: height / 2 + worldPx * (latYFrac(p.lat) - latYFrac(camera.lat)),
      ),
  ];
}
