import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:maplibre/maplibre.dart';

import '../core/theme/app_colors.dart';
import '../domain/activity_type.dart';
import '../domain/route_markers.dart';
import '../domain/route_progress.dart' show RouteTrack;
import '../features/onboarding/activity_type_ui.dart';
import 'live_map_geojson.dart';
import 'preview_projection.dart';
import 'route_marker_painter.dart';

/// Whether the current-position marker is the activity icon badge (true) or the
/// plain blue dot (false). Mirrors Android `MovingMarkerMap`: null/OTHER → dot,
/// every other activity → an amber badge with the white activity glyph.
bool rideMarkerIsBadge(ActivityType? type) =>
    type != null && type != ActivityType.other;

/// Renders the activity badge (Android `makeIconBitmap` parity): a 96px circle
/// in the brand primary with the activity glyph tinted white, drawn with 18px
/// padding so the 960-unit glyph fills the centre 60×60. [loader] supplies the
/// glyph; `_activityBadgePng` passes an [SvgAssetLoader], tests an
/// [SvgStringLoader]. The viewBox transform is proven by `activity_badge_test`:
/// vector_graphics bakes the viewBox origin, so there is NO `translate(0,960)`.
@visibleForTesting
Future<Uint8List> activityBadgePngFromLoader(BytesLoader loader) async {
  const size = 96.0, pad = 18.0, inner = size - 2 * pad; // 60
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  // The badge is rendered to a PNG without a BuildContext, so it reads the
  // light palette's token directly rather than duplicating its hex.
  canvas.drawCircle(
    const Offset(size / 2, size / 2),
    size / 2,
    Paint()..color = AppColors.light.primary,
  );
  final info = await vg.loadPicture(loader, null);
  canvas.saveLayer(
    const Rect.fromLTWH(0, 0, size, size),
    Paint()
      ..colorFilter = ColorFilter.mode(AppColors.light.onMap, BlendMode.srcIn),
  );
  canvas.save();
  canvas.translate(pad, pad);
  canvas.scale(inner / 960);
  canvas.drawPicture(info.picture); // NO translate(0,960) — origin pre-baked.
  canvas.restore();
  canvas.restore();
  info.picture.dispose();
  final img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return bytes!.buffer.asUint8List();
}

Future<Uint8List> _activityBadgePng(ActivityType type) =>
    activityBadgePngFromLoader(SvgAssetLoader(type.iconAsset));

/// Adds the live map's sources, layers and images to one loaded [style].
///
/// Every method returns early once the load was [superseded] (issue #47: the
/// map was detached or a newer style loaded), so an old load never adds
/// layers to a dead map; the caller checks [superseded] after each call.
class LiveMapLayers {
  LiveMapLayers({
    required this.style,
    required this.colors,
    required this.pixelRatio,
    required this.superseded,
  }) : halo = mapHex(colors.routeLineHalo),
       blue = mapHex(colors.routeLineBlue);

  final StyleController style;
  final AppColors colors;
  final double pixelRatio;

  /// True when this style's load was overtaken.
  final bool Function() superseded;

  /// `#RRGGBB` of the route line's halo and blue.
  final String halo;
  final String blue;

  /// Badge images already registered on the style (`addImage` would throw on a
  /// duplicate id), so a live activity swap only rasterizes each type once.
  final Set<String> _markerImages = {};

  static const _lineLayout = {'line-cap': 'round', 'line-join': 'round'};

  /// The followed reference (Spec 17): its line and the ridden parts (Spec 18)
  /// on top, added first so every live layer draws above them.
  Future<void> addReference(
    RouteTrack reference,
    List<List<RoutePoint>>? done,
  ) async {
    final g = referenceGeoJson(reference, done);
    await style.addSource(GeoJsonSource(id: 'reference', data: g.ahead));
    if (superseded()) return;
    await style.addSource(GeoJsonSource(id: 'reference-done', data: g.done));
    if (superseded()) return;
    final layers = [
      LineStyleLayer(
        id: 'reference-halo',
        sourceId: 'reference',
        layout: _lineLayout,
        paint: {
          'line-color': halo,
          'line-width': 8.0,
          'line-opacity': kReferenceRouteOpacity,
        },
      ),
      LineStyleLayer(
        id: 'reference-line',
        sourceId: 'reference',
        layout: _lineLayout,
        paint: {
          'line-color': blue,
          'line-width': 4.5,
          'line-opacity': kReferenceRouteOpacity,
        },
      ),
      LineStyleLayer(
        id: 'reference-done-line',
        sourceId: 'reference-done',
        layout: _lineLayout,
        paint: {
          'line-color': mapHex(colors.onSurfaceVariant),
          'line-width': 4.5,
          'line-opacity': kReferenceRouteOpacity,
        },
      ),
    ];
    for (final layer in layers) {
      await style.addLayer(layer);
      if (superseded()) return;
    }
  }

  /// The recorded route: halo, line and direction arrowheads; with a
  /// [reference], its own arrowheads below the live route.
  Future<void> addRoute(
    List<RoutePoint> points, {
    RouteTrack? reference,
  }) async {
    await style.addSource(
      GeoJsonSource(id: 'route', data: routeLineGeoJson(points)),
    );
    if (superseded()) return;
    await style.addLayer(
      LineStyleLayer(
        id: 'route-halo',
        sourceId: 'route',
        layout: _lineLayout,
        paint: {'line-color': halo, 'line-width': 8.0},
      ),
    );
    if (superseded()) return;
    await style.addLayer(
      LineStyleLayer(
        id: 'route-line',
        sourceId: 'route',
        layout: _lineLayout,
        paint: {'line-color': blue, 'line-width': 4.5},
      ),
    );
    if (superseded()) return;
    // Direction arrowheads, placed and rotated along the line by MapLibre.
    final arrow = symbolRaster(arrowIconSize, pixelRatio);
    final arrowPng = await routeArrowImagePng(colors, arrow.rasterRatio);
    if (superseded()) return;
    await style.addImage(arrowImageId, arrowPng);
    if (superseded()) return;
    final layout = {
      'symbol-placement': 'line',
      'symbol-spacing': arrowSpacingPx,
      'icon-image': arrowImageId,
      'icon-size': arrow.iconSize,
      'icon-rotation-alignment': 'map',
      'icon-keep-upright': false,
      'icon-allow-overlap': true,
      'icon-ignore-placement': true,
    };
    await style.addLayer(
      SymbolStyleLayer(id: 'route-arrows', sourceId: 'route', layout: layout),
    );
    if (superseded() || reference == null) return;
    // The reference's own arrowheads reuse the image registered just above
    // (a second addImage of the same id throws), below the live route.
    await style.addLayer(
      SymbolStyleLayer(
        id: 'reference-arrows',
        sourceId: 'reference',
        layout: layout,
        paint: const {'icon-opacity': kReferenceRouteOpacity},
      ),
      belowLayerId: 'route-halo',
    );
  }

  /// The live line's last stretch, drawn up to the gliding marker (see
  /// `MarkerGlide.pushTail`) in the route's own halo + blue.
  Future<void> addTail() async {
    await style.addSource(
      const GeoJsonSource(id: 'route-tail', data: emptyGeoJson),
    );
    if (superseded()) return;
    // Halo BELOW the route's blue line: on top, its wider white cap would
    // cut a white crescent into the blue where body and tail meet.
    await style.addLayer(
      LineStyleLayer(
        id: 'route-tail-halo',
        sourceId: 'route-tail',
        layout: _lineLayout,
        paint: {'line-color': halo, 'line-width': 8.0},
      ),
      belowLayerId: 'route-line',
    );
    if (superseded()) return;
    await style.addLayer(
      LineStyleLayer(
        id: 'route-tail-line',
        sourceId: 'route-tail',
        layout: _lineLayout,
        paint: {'line-color': blue, 'line-width': 4.5},
      ),
    );
  }

  /// The start / finish (or combined loop) markers of [points] on the point
  /// sources [startId] and [endId]. Returns the endpoint style drawn.
  Future<RouteEndpointStyle> addEndpoints(
    String startId,
    String endId,
    List<RoutePoint> points,
  ) async {
    final endpoints = routeEndpointStyle(points);
    switch (endpoints) {
      case RouteEndpointStyle.none:
        break;
      case RouteEndpointStyle.startOnly:
        await _addEndpointMarker(startId, points.first, RouteMarkerImage.start);
      case RouteEndpointStyle.open:
        await _addEndpointMarker(startId, points.first, RouteMarkerImage.start);
        if (superseded()) return endpoints;
        await _addEndpointMarker(endId, points.last, RouteMarkerImage.finish);
      case RouteEndpointStyle.loop:
        await _addEndpointMarker(startId, points.first, RouteMarkerImage.loop);
    }
    return endpoints;
  }

  /// A start/finish/loop marker (see route_marker_painter.dart) as a symbol on
  /// its own point source [id].
  Future<void> _addEndpointMarker(
    String id,
    RoutePoint at,
    RouteMarkerImage kind,
  ) async {
    final imageId = 'endpoint-${kind.name}';
    final raster = symbolRaster(mapEndpointMarkerScale, pixelRatio);
    final png = await routeMarkerImagePng(kind, colors, raster.rasterRatio);
    if (superseded()) return;
    await style.addImage(imageId, png);
    if (superseded()) return;
    await style.addSource(GeoJsonSource(id: id, data: pointGeoJson(at)));
    if (superseded()) return;
    await style.addLayer(
      SymbolStyleLayer(
        id: '$id-marker',
        sourceId: id,
        layout: {
          'icon-image': imageId,
          'icon-size': raster.iconSize,
          'icon-allow-overlap': true,
          'icon-ignore-placement': true,
        },
      ),
    );
  }

  /// Seeds the `current` source with [current] (empty until there is a fix)
  /// and adds the live marker for [type].
  Future<void> addCurrent(RoutePoint? current, ActivityType? type) async {
    await style.addSource(
      GeoJsonSource(
        id: 'current',
        data: current != null ? pointGeoJson(current) : emptyGeoJson,
      ),
    );
    if (superseded()) return;
    await addCurrentMarker(type);
  }

  /// Adds the live `current-dot` marker layer for [type]: the amber activity
  /// badge (Android `makeIconBitmap` parity) for known types, or the plain blue
  /// dot for null/OTHER. Each badge image is rasterized once.
  Future<void> addCurrentMarker(ActivityType? type) async {
    if (rideMarkerIsBadge(type)) {
      final imageId = 'marker-${type!.name}';
      if (_markerImages.add(imageId)) {
        final png = await _activityBadgePng(type);
        if (superseded()) return;
        await style.addImage(imageId, png);
        if (superseded()) return;
      }
      await style.addLayer(
        SymbolStyleLayer(
          id: 'current-dot',
          sourceId: 'current',
          layout: {
            'icon-image': imageId,
            // maplibre 0.3.5 fixed Android's addImage() to respect
            // devicePixelRatio (it previously registered bitmaps at raw-pixel
            // size, rendering symbols ~pixelRatio× too small there). That made
            // this 96px badge render correctly-sized but much larger than the
            // pre-upgrade appearance this value was tuned against. 0.19 (~18dp
            // on a 420dpi/2.625x device) restores that footprint, now
            // consistently across every device rather than shrinking on
            // higher-density screens as before.
            'icon-size': 0.19,
            'icon-allow-overlap': true,
            'icon-ignore-placement': true,
          },
        ),
      );
    } else {
      await style.addLayer(
        CircleStyleLayer(
          id: 'current-dot',
          sourceId: 'current',
          paint: {
            'circle-radius': 7.0,
            'circle-color': blue,
            'circle-stroke-width': 3.0,
            'circle-stroke-color': mapHex(colors.onMap),
          },
        ),
      );
    }
  }

  /// Replaces the live `current-dot` marker after the ride's activity changes
  /// (committed only when tracking starts, so it lands as a prop change after
  /// the style has loaded).
  Future<void> swapCurrentMarker(ActivityType? type) async {
    await style.removeLayer('current-dot');
    if (superseded()) return;
    await addCurrentMarker(type);
  }
}
