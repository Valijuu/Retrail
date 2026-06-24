import 'dart:math' as math;

/// A route coordinate (latitude, longitude). Structurally identical to the
/// tracking layer's `RoutePoint`, so the two interoperate.
typedef RoutePoint = ({double lat, double lng});

/// A projected pixel position within the preview slot (dp).
typedef PreviewOffset = ({double x, double y});

/// Max preview zoom. Higher zoom on short/standstill rides yields a featureless
/// tile (no streets); z16 is street-level with enough context. Also the default
/// for the degenerate single-point ride. Ported from the original `StaticRouteMap`.
const double maxPreviewZoom = 16.0;

/// Web-Mercator framing for a preview slot.
class StaticFraming {
  const StaticFraming({
    required this.centerLat,
    required this.centerLon,
    required this.zoom,
    required this.widthDp,
    required this.heightDp,
  });

  final double centerLat;
  final double centerLon;
  final double zoom;
  final int widthDp;
  final int heightDp;
}

double _log2(double x) => math.log(x) / math.ln2;

/// Computes the bounding-box center + fit zoom for [points] in a [widthDp] ×
/// [heightDp] slot. Caps zoom at [maxPreviewZoom]; degenerate boxes
/// (single point / standstill jitter) use [maxPreviewZoom] directly.
StaticFraming computeFraming(List<RoutePoint> points, int widthDp, int heightDp) {
  final lats = points.map((p) => p.lat);
  final lons = points.map((p) => p.lng);
  final north = lats.reduce(math.max);
  final south = lats.reduce(math.min);
  final east = lons.reduce(math.max);
  final west = lons.reduce(math.min);
  final centerLat = (north + south) / 2.0;
  final centerLon = (east + west) / 2.0;

  const padDp = 16;
  final targetW = math.max(widthDp - 2 * padDp, 1);
  final targetH = math.max(heightDp - 2 * padDp, 1);
  final lonFrac = (east - west) / 360.0;
  final latFrac = latYFrac(south) - latYFrac(north);

  final double zoom;
  if (lonFrac < 1e-7 && latFrac < 1e-7) {
    // Degenerate bbox: no span to fit → a sensible street-level default.
    zoom = maxPreviewZoom;
  } else {
    final safeLonFrac = math.max(lonFrac, 1e-9);
    final safeLatFrac = math.max(latFrac, 1e-9);
    final zoomLon = _log2(targetW / (256.0 * safeLonFrac));
    final zoomLat = _log2(targetH / (256.0 * safeLatFrac));
    // Integer zoom (tile math needs int; floor also guarantees the route fits);
    // capped so tiny rides don't zoom to z19 and show a featureless tile.
    zoom = math.min(zoomLon, zoomLat).floorToDouble().clamp(1.0, maxPreviewZoom);
  }
  return StaticFraming(
    centerLat: centerLat,
    centerLon: centerLon,
    zoom: zoom,
    widthDp: widthDp,
    heightDp: heightDp,
  );
}

double latYFrac(double lat) {
  final s = math.sin(lat * math.pi / 180.0).clamp(-0.9999, 0.9999);
  return 0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi);
}

double lonXAtZoom(double lon, double zoom) =>
    256.0 * math.pow(2.0, zoom) * (lon + 180.0) / 360.0;

double latYAtZoom(double lat, double zoom) =>
    256.0 * math.pow(2.0, zoom) * latYFrac(lat);

/// Projects a coordinate to a pixel offset within the framing's slot.
PreviewOffset projectPoint(RoutePoint p, StaticFraming f) {
  final cx = lonXAtZoom(f.centerLon, f.zoom);
  final cy = latYAtZoom(f.centerLat, f.zoom);
  final px = lonXAtZoom(p.lng, f.zoom) - cx + f.widthDp / 2.0;
  final py = latYAtZoom(p.lat, f.zoom) - cy + f.heightDp / 2.0;
  return (x: px, y: py);
}
