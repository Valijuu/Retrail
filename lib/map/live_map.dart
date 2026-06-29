import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_colors.dart';
import 'map_config.dart';
import 'preview_projection.dart';

/// What the camera should do on a [LiveMap] update. Pure, so the follow /
/// recenter rules are unit-tested without pumping the map.
class CameraFollow {
  const CameraFollow({required this.resetZoom});

  /// True when the move should also restore the ride zoom (an explicit recenter
  /// tap), false to keep the user's current zoom (passive follow on a new fix).
  final bool resetZoom;
}

/// Decides whether to move the camera to the current position on a widget update:
/// - **Recenter just pressed** (follow off→on): move now and restore zoom, even
///   without a new fix — this is what makes the recenter button responsive.
/// - **Following + a new fix**: keep the rider centered at the current zoom.
/// - **Not following**: never move (respect the user's pan/zoom).
CameraFollow? followCameraUpdate({
  required bool wasFollowing,
  required bool isFollowing,
  required bool hasCurrent,
  required bool currentChanged,
}) {
  if (!hasCurrent) return null;
  final justRecentered = isFollowing && !wasFollowing;
  if (justRecentered) return const CameraFollow(resetZoom: true);
  if (isFollowing && currentChanged) return const CameraFollow(resetZoom: false);
  return null;
}

/// Bounding box enclosing every point of [points], or null when empty. Used to
/// frame the whole route (read-only detail / fullscreen) instead of centring on
/// the last point. Pure, so the framing is unit-tested without pumping the map.
LatLngBounds? routeBounds(List<RoutePoint> points) {
  if (points.isEmpty) return null;
  return LatLngBounds.fromPoints(
      [for (final p in points) LatLng(p.lat, p.lng)]);
}

/// Interactive-map zoom bounds. Without a floor, flutter_map lets you pinch out
/// without limit to a tiny repeated-world speck that janks the frame and makes
/// the ride controls hard to hit; the ceiling caps it at useful street detail.
/// Low enough that [LiveMap.fitBounds] still frames any realistic ride.
const double kLiveMapMinZoom = 3.0;
const double kLiveMapMaxZoom = 19.0;

/// Live/active-ride map (`flutter_map`): MapTiler raster basemap with the
/// halo + blue route polyline drawn on Flutter's canvas, plus start/end and
/// current-position markers. Camera follows the current position.
///
/// Heading-up rotation and follow smoothness are tuned/verified on-device
/// (Spec 5 Part B); this builds the widget and renders a static route.
class LiveMap extends StatefulWidget {
  const LiveMap({
    super.key,
    required this.points,
    this.current,
    this.isFollowing = true,
    this.initialZoom = 16.5,
    this.fitBounds = false,
    this.onGesture,
  });

  final List<RoutePoint> points;
  final RoutePoint? current;

  /// Whether the camera tracks the rider. Tapping recenter flips this true,
  /// which snaps the camera back to the current position (see [didUpdateWidget]).
  final bool isFollowing;
  final double initialZoom;

  /// Frame the whole route (read-only detail / fullscreen) instead of centring
  /// on the last point at [initialZoom]. The active-ride map leaves this false
  /// so it keeps its follow / recenter behaviour.
  final bool fitBounds;

  /// Fired when the user pans/zooms the map by hand, so the screen can drop
  /// camera-follow (and show the recenter control). Mirrors the original's
  /// `onGestureDetected`.
  final VoidCallback? onGesture;

  @override
  State<LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends State<LiveMap> {
  final MapController _controller = MapController();

  // One provider for the widget's lifetime (not rebuilt per GPS fix): disk-cached
  // + cancels obsolete requests, so revisited / zoomed-out tiles load from disk
  // instead of refetching. flutter_map disposes it with the TileLayer.
  final TileProvider _tileProvider = NetworkTileProvider(
    cachingProvider: BuiltInMapCachingProvider.getOrCreateInstance(
      maxCacheSize: 256 * 1024 * 1024, // 256 MB on-device tile cache
      // Treat cached tiles as fresh for a week so a ride that loses signal still
      // renders any street tiles already viewed (served from disk, no network):
      // without this, a stale tile is refetched and falls back to a blank tile
      // when offline instead of using the bytes already on disk.
      overrideFreshAge: const Duration(days: 7),
    ),
  );

  LatLng get _center {
    final c = widget.current ??
        (widget.points.isNotEmpty ? widget.points.last : null);
    return c != null ? LatLng(c.lat, c.lng) : const LatLng(0, 0);
  }

  @override
  void didUpdateWidget(LiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final decision = followCameraUpdate(
      wasFollowing: oldWidget.isFollowing,
      isFollowing: widget.isFollowing,
      hasCurrent: widget.current != null,
      currentChanged: widget.current != oldWidget.current,
    );
    if (decision != null) {
      _controller.move(
        _center,
        decision.resetZoom ? widget.initialZoom : _controller.camera.zoom,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final route = [for (final p in widget.points) LatLng(p.lat, p.lng)];

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: _center,
        initialZoom: widget.initialZoom,
        minZoom: kLiveMapMinZoom,
        maxZoom: kLiveMapMaxZoom,
        // Fill not-yet-loaded tiles with the map terrain colour instead of
        // flutter_map's default grey, so zoom-out / fast-pan gaps blend in.
        backgroundColor: colors.mapTerrain,
        // Frame the whole route when requested; takes precedence over
        // initialCenter/zoom in flutter_map, so the active-ride map (fitBounds
        // false) is unaffected. 24dp padding mirrors the original.
        initialCameraFit: widget.fitBounds && widget.points.isNotEmpty
            ? CameraFit.bounds(
                bounds: routeBounds(widget.points)!,
                padding: const EdgeInsets.all(24),
              )
            : null,
        onPositionChanged: (camera, hasGesture) {
          if (hasGesture) widget.onGesture?.call();
        },
      ),
      children: [
        TileLayer(
          urlTemplate: MapConfig.rasterUrlTemplate(dark),
          userAgentPackageName: 'com.retrail.retrail',
          tileProvider: _tileProvider,
          // Preload a one-tile ring around the viewport so a zoom-out/pan
          // reveals already-loaded tiles rather than momentary blanks.
          panBuffer: 2,
        ),
        if (route.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(points: route, strokeWidth: 8, color: colors.routeLineHalo),
              Polyline(points: route, strokeWidth: 4.5, color: colors.routeLineBlue),
            ],
          ),
        MarkerLayer(
          markers: [
            if (widget.points.isNotEmpty)
              _dot(widget.points.first, colors.markerStartGreen),
            if (widget.points.length >= 2)
              _dot(widget.points.last, colors.markerEndRed),
            if (widget.current != null)
              _dot(widget.current!, colors.routeLineBlue, ring: true),
          ],
        ),
        // Required basemap attribution (MapTiler tiles over OpenStreetMap data).
        // The original relied on MapLibre's built-in bottom-end attribution;
        // flutter_map has none, so it is rendered explicitly here.
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              '© MapTiler',
              onTap: () => launchUrl(
                Uri.parse('https://www.maptiler.com/copyright/'),
              ),
            ),
            TextSourceAttribution(
              '© OpenStreetMap contributors',
              onTap: () => launchUrl(
                Uri.parse('https://www.openstreetmap.org/copyright'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Marker _dot(RoutePoint p, Color color, {bool ring = false}) => Marker(
        point: LatLng(p.lat, p.lng),
        width: 18,
        height: 18,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: ring ? Border.all(color: Colors.white, width: 3) : null,
          ),
        ),
      );
}
