import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:maplibre/maplibre.dart';

import '../core/theme/app_colors.dart';
import '../domain/activity_type.dart';
import '../domain/distance_calculator.dart';
import '../features/onboarding/activity_type_ui.dart';
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

/// Bounding box enclosing every point of [points], or null when empty. Feeds
/// MapLibre's `controller.fitBounds` directly, so the read-only detail /
/// fullscreen map frames the whole route instead of centring on the last point.
/// Pure, so the framing is unit-tested without pumping the map.
LngLatBounds? routeBounds(List<RoutePoint> points) {
  if (points.isEmpty) return null;
  return LngLatBounds.fromPoints(
      [for (final p in points) Position(p.lng, p.lat)]);
}

/// Live-map MapLibre style URL for the current brightness. Pure, so the
/// style choice is unit-tested without a real key or a rendered map.
String liveMapStyleUrl(bool dark) => MapConfig.vectorStyleUrl(dark);

/// An empty GeoJSON source payload — a valid document MapLibre accepts when
/// there is nothing to draw yet (a 0/1-point route or an unseeded marker).
const String _emptyGeoJson = '{"type":"FeatureCollection","features":[]}';

/// GeoJSON source data for the recorded route (lng,lat order). Pure, so the
/// geometry that feeds the MapLibre source is unit-tested without a map. A
/// LineString needs ≥2 points — MapLibre rejects fewer ("A line string must
/// have two or more coordinate points") — so a 0/1-point route yields the empty
/// document instead.
String routeLineGeoJson(List<RoutePoint> points) {
  if (points.length < 2) return _emptyGeoJson;
  return jsonEncode({
    'type': 'Feature',
    'geometry': {
      'type': 'LineString',
      'coordinates': [for (final p in points) [p.lng, p.lat]],
    },
    'properties': <String, Object?>{},
  });
}

/// Linear interpolation between two coordinates. Safe for the short per-fix
/// distances the marker glide covers (metres — curvature is irrelevant).
RoutePoint lerpPoint(RoutePoint a, RoutePoint b, double t) =>
    (lat: a.lat + (b.lat - a.lat) * t, lng: a.lng + (b.lng - a.lng) * t);

/// Above this jump the current-position marker snaps instead of gliding: a GPS
/// recovery / teleport animated over 600 ms would be a distracting slow slide
/// across the screen. Normal 1 Hz fixes move a few metres.
const double _markerSnapThresholdM = 150;

/// Whether the marker should snap straight to [to] (true) or glide from [from]
/// (false). Pure, so the decision is unit-tested without pumping the map.
bool markerShouldSnap(RoutePoint from, RoutePoint to) =>
    const HaversineDistanceCalculator()
        .distanceBetween(from.lat, from.lng, to.lat, to.lng) >
    _markerSnapThresholdM;

String _pointGeoJson(RoutePoint p) => jsonEncode({
      'type': 'Feature',
      'geometry': {'type': 'Point', 'coordinates': [p.lng, p.lat]},
      'properties': <String, Object?>{},
    });

/// `#RRGGBB` for a token [Color], the form MapLibre paint properties expect.
/// `toARGB32()` is the non-deprecated 32-bit accessor (replaces `Color.value`).
String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

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
  canvas.drawCircle(const Offset(size / 2, size / 2), size / 2,
      Paint()..color = AppColors.light.primary);
  final info = await vg.loadPicture(loader, null);
  canvas.saveLayer(
      const Rect.fromLTWH(0, 0, size, size),
      Paint()
        ..colorFilter =
            const ColorFilter.mode(Color(0xFFFFFFFF), BlendMode.srcIn));
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

/// Interactive-map zoom bounds. Without a floor, you could pinch out without
/// limit to a tiny repeated-world speck that janks the frame and makes the ride
/// controls hard to hit; the ceiling caps it at useful street detail. Low enough
/// that [LiveMap.fitBounds] still frames any realistic ride.
const double kLiveMapMinZoom = 3.0;
const double kLiveMapMaxZoom = 19.0;

/// Live/active-ride map: a native MapLibre vector basemap (topo-v2 / basic-v2-dark)
/// with the halo + blue route line and start/end + current-position dots drawn as
/// GeoJSON source layers. The camera follows the current position.
///
/// Heading-up rotation and follow smoothness are tuned/verified on-device
/// (Spec 5 Part B); this builds the widget and renders the route.
class LiveMap extends StatefulWidget {
  const LiveMap({
    super.key,
    required this.points,
    this.current,
    this.isFollowing = true,
    this.initialZoom = 16.5,
    this.fitBounds = false,
    this.activityType,
    this.onGesture,
  });

  final List<RoutePoint> points;
  final RoutePoint? current;

  /// The ride's activity, deciding the live current-position marker: an amber
  /// badge with the white activity glyph for known types, the plain blue dot
  /// for null/OTHER (see [rideMarkerIsBadge]). Ignored when [fitBounds] (the
  /// detail map draws start/end dots, no current marker).
  final ActivityType? activityType;

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

  /// Test seam: when non-null, every [LiveMap] (built directly OR inside a
  /// screen) renders this instead of the native [MapLibreMap]. The native map
  /// throws `UnimplementedError` under `flutter test`, so screen/widget tests
  /// set this in `setUp` and clear it in `tearDown`. Null in production → real
  /// map. Mirrors Flutter's own `debugDefaultTargetPlatformOverride` pattern.
  @visibleForTesting
  static Widget Function(BuildContext context)? debugMapBuilderOverride;

  @override
  State<LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends State<LiveMap>
    with SingleTickerProviderStateMixin {
  MapController? _controller;
  StyleController? _style;

  /// Glides the current-position marker between fixes (600 ms — matching the
  /// camera's animateCamera — and linear, so constant motion between ~1 Hz
  /// fixes doesn't pulse). Without it the dot teleports while the camera glides.
  /// Created in [initState]: a lazy `late final` would first run in [dispose],
  /// where the TickerMode ancestor lookup throws on the deactivated element.
  late final AnimationController _glide;

  /// Where the marker is currently drawn (the glide's moving position), so a
  /// fix arriving mid-glide restarts from here — no lag buildup, no jump back.
  RoutePoint? _renderedCurrent;
  RoutePoint? _glideFrom;
  RoutePoint? _glideTo;

  /// Last time a glide frame was pushed to the source, for throttling the
  /// platform-channel updates to ~25 fps instead of display rate.
  int _lastGlidePushMs = 0;

  @override
  void initState() {
    super.initState();
    _glide = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(_onGlideTick);
  }

  /// Badge images already registered on the style (`addImage` would throw on a
  /// duplicate id), so a live activity swap only rasterizes each type once.
  final Set<String> _markerImages = {};

  /// True once the live `current-dot` marker has been added in [_onStyleLoaded]
  /// — gates the live activity-marker swap so it never tries to remove a layer
  /// that the style load hasn't created yet.
  bool _markerReady = false;

  /// True once the style has loaded and the camera has centered, at which point
  /// the terrain placeholder crossfades out to reveal the positioned map. Stays
  /// true after the first reveal so a later brightness reload doesn't re-flash
  /// the placeholder.
  bool _styleReady = false;

  /// Centre target: the current fix if any, else the last recorded point.
  Position get _centerPosition {
    final c = widget.current ??
        (widget.points.isNotEmpty ? widget.points.last : null);
    return c != null ? Position(c.lng, c.lat) : Position(0, 0);
  }

  @override
  void didUpdateWidget(LiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Push live geometry updates into the existing sources (no style reload).
    // The live map has no start/end dots (only the current marker), and the
    // detail map's points are fixed — so only the route + current need updating.
    if (widget.points != oldWidget.points) {
      _style?.updateGeoJsonSource(
          id: 'route', data: routeLineGeoJson(widget.points));
    }
    if (!widget.fitBounds &&
        widget.current != oldWidget.current &&
        widget.current != null) {
      _glideMarkerTo(widget.current!);
    }
    // The ride's activity is committed in RideTracker.startTracking() — which
    // runs after this map's style has already loaded — so activityType arrives
    // as a prop change. Swap the current marker to match instead of leaving the
    // one registered at style-load (which was the previous ride's activity).
    if (!widget.fitBounds &&
        _markerReady &&
        widget.activityType != oldWidget.activityType) {
      _swapCurrentMarker();
    }
    final decision = followCameraUpdate(
      wasFollowing: oldWidget.isFollowing,
      isFollowing: widget.isFollowing,
      hasCurrent: widget.current != null,
      currentChanged: widget.current != oldWidget.current,
    );
    if (decision != null) {
      _ignoreCancel(_controller?.animateCamera(
        center: _centerPosition,
        zoom: decision.resetZoom
            ? widget.initialZoom
            : (_controller?.camera?.zoom ?? widget.initialZoom),
        nativeDuration: const Duration(milliseconds: 600),
      ));
    }
  }

  /// Moves the `current` marker to [next]: a glide from where it is drawn now,
  /// or a direct snap when there is no previous position, or the jump is big
  /// enough (GPS recovery) that a 600 ms slide would look wrong.
  void _glideMarkerTo(RoutePoint next) {
    final from = _renderedCurrent;
    if (from == null || markerShouldSnap(from, next)) {
      _glide.stop();
      _renderedCurrent = next;
      _style?.updateGeoJsonSource(id: 'current', data: _pointGeoJson(next));
      return;
    }
    _glideFrom = from; // mid-glide restart begins at the interpolated position
    _glideTo = next;
    _glide
      ..stop()
      ..forward(from: 0);
  }

  /// Per-frame glide tick: pushes the interpolated position into the `current`
  /// source, throttled to ≥40 ms between pushes (~25 fps) so the platform
  /// channel isn't spammed at display rate. The final frame always lands.
  void _onGlideTick() {
    final from = _glideFrom, to = _glideTo;
    if (from == null || to == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!_glide.isCompleted && now - _lastGlidePushMs < 40) return;
    _lastGlidePushMs = now;
    final p = lerpPoint(from, to, _glide.value);
    _renderedCurrent = p;
    _style?.updateGeoJsonSource(id: 'current', data: _pointGeoJson(p));
  }

  /// A camera move can be superseded by the next one (every fix recenters),
  /// which completes the in-flight future with `Exception: Animation cancelled`.
  /// That's expected — attach a handler so it isn't an unhandled exception.
  void _ignoreCancel(Future<void>? future) {
    future?.catchError((Object _) {});
  }

  Future<void> _onStyleLoaded(StyleController style) async {
    _style = style;
    // A fresh style (e.g. a brightness rebuild) carries none of the previously
    // registered images/layers, so re-rasterize badges from scratch — and stop
    // any in-flight marker glide so its ticks can't touch the `current` source
    // before this load recreates it.
    _glide.stop();
    _glideFrom = null;
    _glideTo = null;
    _markerReady = false;
    _markerImages.clear();
    final colors = Theme.of(context).extension<AppColors>()!;
    final halo = _hex(colors.routeLineHalo);
    final blue = _hex(colors.routeLineBlue);
    final green = _hex(colors.markerStartGreen);
    final red = _hex(colors.markerEndRed);

    await style.addSource(
        GeoJsonSource(id: 'route', data: routeLineGeoJson(widget.points)));
    await style.addLayer(LineStyleLayer(
      id: 'route-halo',
      sourceId: 'route',
      layout: const {'line-cap': 'round', 'line-join': 'round'},
      paint: {'line-color': halo, 'line-width': 8.0},
    ));
    await style.addLayer(LineStyleLayer(
      id: 'route-line',
      sourceId: 'route',
      layout: const {'line-cap': 'round', 'line-join': 'round'},
      paint: {'line-color': blue, 'line-width': 4.5},
    ));

    // Marker mode mirrors the two original composables: the detail / fullscreen
    // map (fitBounds) draws green start + red end dots and NO current marker;
    // the live / active-ride map draws ONLY the current-position marker.
    if (widget.fitBounds) {
      if (widget.points.isNotEmpty) {
        await style.addSource(GeoJsonSource(
            id: 'start', data: _pointGeoJson(widget.points.first)));
        await style.addLayer(CircleStyleLayer(
          id: 'start-dot',
          sourceId: 'start',
          // Same dot styling as the blue current marker (radius 7 + 3px white
          // ring), in the start colour.
          paint: {
            'circle-radius': 7.0,
            'circle-color': green,
            'circle-stroke-width': 3.0,
            'circle-stroke-color': '#FFFFFF',
          },
        ));
      }
      if (widget.points.length >= 2) {
        await style.addSource(GeoJsonSource(
            id: 'end', data: _pointGeoJson(widget.points.last)));
        await style.addLayer(CircleStyleLayer(
          id: 'end-dot',
          sourceId: 'end',
          paint: {
            'circle-radius': 7.0,
            'circle-color': red,
            'circle-stroke-width': 3.0,
            'circle-stroke-color': '#FFFFFF',
          },
        ));
      }
    } else {
      // Current-position marker, updated per fix via updateGeoJsonSource (see
      // didUpdateWidget). Seeded empty until there is a fix.
      final cur = widget.current;
      _renderedCurrent = cur; // glide baseline = the seeded marker position
      await style.addSource(GeoJsonSource(
        id: 'current',
        data: cur != null ? _pointGeoJson(cur) : _emptyGeoJson,
      ));
      await _addCurrentMarker(style, widget.activityType, blue);
      _markerReady = true;
    }

    if (widget.fitBounds && widget.points.isNotEmpty) {
      _ignoreCancel(_controller?.fitBounds(
        bounds: routeBounds(widget.points)!,
        padding: const EdgeInsets.all(24),
      ));
    } else if (!widget.fitBounds && widget.isFollowing) {
      // Recenter once the style is ready. The map is created with initCenter
      // (0,0) when the ride starts with no fix yet; the follow update in
      // didUpdateWidget is skipped if the first fix arrives before the
      // controller exists, which would leave the camera stranded at null island
      // (a blank light-blue ocean) even though recording works. Snapping here —
      // when the controller and style are both ready — recovers that race.
      final c = widget.current ??
          (widget.points.isNotEmpty ? widget.points.last : null);
      if (c != null) {
        _ignoreCancel(_controller?.moveCamera(
          center: Position(c.lng, c.lat),
          zoom: widget.initialZoom,
        ));
      }
    }

    // Style loaded and camera centered — reveal the map (crossfade the terrain
    // placeholder out). Set in a frame callback so the camera move above has
    // applied before the map becomes visible (no flash of the (0,0) frame).
    if (mounted && !_styleReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _styleReady = true);
      });
    }
  }

  /// Adds the live `current-dot` marker layer for [type]: the amber activity
  /// badge (Android `makeIconBitmap` parity) for known types, or the plain blue
  /// dot ([blue]) for null/OTHER. Each badge image is rasterized once.
  Future<void> _addCurrentMarker(
      StyleController style, ActivityType? type, String blue) async {
    if (rideMarkerIsBadge(type)) {
      final imageId = 'marker-${type!.name}';
      if (_markerImages.add(imageId)) {
        await style.addImage(imageId, await _activityBadgePng(type));
      }
      await style.addLayer(SymbolStyleLayer(
        id: 'current-dot',
        sourceId: 'current',
        layout: {
          'icon-image': imageId,
          'icon-size': 0.5,
          'icon-allow-overlap': true,
          'icon-ignore-placement': true,
        },
      ));
    } else {
      await style.addLayer(CircleStyleLayer(
        id: 'current-dot',
        sourceId: 'current',
        paint: {
          'circle-radius': 7.0,
          'circle-color': blue,
          'circle-stroke-width': 3.0,
          'circle-stroke-color': '#FFFFFF',
        },
      ));
    }
  }

  /// Replaces the live `current-dot` marker after [LiveMap.activityType] changes
  /// (the ride's activity is committed only when tracking starts, so it lands as
  /// a prop change after the style has loaded).
  Future<void> _swapCurrentMarker() async {
    final style = _style;
    if (style == null || !mounted) return;
    final blue = _hex(Theme.of(context).extension<AppColors>()!.routeLineBlue);
    await style.removeLayer('current-dot');
    await _addCurrentMarker(style, widget.activityType, blue);
  }

  @override
  void dispose() {
    _glide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final override = LiveMap.debugMapBuilderOverride;
    if (override != null) return override(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).extension<AppColors>()!;
    return Stack(
      fit: StackFit.expand,
      children: [
        MapLibreMap(
          // Rebuild on brightness change to reload topo-v2/basic-v2-dark
          // (no runtime setStyle in maplibre 0.2.2).
          key: ValueKey(dark),
          options: MapOptions(
            initStyle: liveMapStyleUrl(dark),
            initCenter: _centerPosition,
            initZoom: widget.initialZoom,
            minZoom: kLiveMapMinZoom,
            maxZoom: kLiveMapMaxZoom,
            // Texture-based composition (trial, issue #11): Hybrid
            // Composition rendered the native map via its own independent
            // Android Surface, and on a real device that surface could get
            // recomposited mid-navigation-transition showing a stale buffer
            // from an unrelated earlier screen (a one-frame flash of the
            // countdown page when leaving /ride). Texture mode routes the
            // map's output through Flutter's own Skia/Impeller frame instead,
            // so there's no separate native surface left to go stale — at
            // the cost of touch/animation smoothness vs. Hybrid Composition.
            androidTextureMode: true,
            androidMode: AndroidPlatformViewMode.tlhc_vd,
          ),
          onMapCreated: (c) => _controller = c,
          onStyleLoaded: _onStyleLoaded,
          onEvent: (e) {
            // Drop follow only on a real user gesture — programmatic moves
            // report developerAnimation/apiAnimation, so our own camera
            // animations don't trip this.
            if (e is MapEventStartMoveCamera &&
                e.reason == CameraChangeReason.apiGesture) {
              widget.onGesture?.call();
            }
          },
        ),
        // Terrain-colored placeholder over the map until the style has loaded
        // and centered, then crossfade it out — so the reveal is a smooth fade
        // to an already-positioned map instead of a flash of the (0,0) ocean or
        // tiles popping in. Fading a plain widget avoids platform-view opacity
        // quirks; IgnorePointer lets gestures through once revealed.
        IgnorePointer(
          ignoring: _styleReady,
          child: AnimatedOpacity(
            opacity: _styleReady ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            child: ColoredBox(color: colors.mapTerrain),
          ),
        ),
      ],
    );
  }
}
