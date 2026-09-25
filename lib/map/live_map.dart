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
import '../domain/route_markers.dart';
import 'preview_projection.dart';
import 'route_marker_painter.dart';
import '../core/theme/theme_context.dart';

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
      [for (final p in points) Geographic(lon: p.lng, lat: p.lat)]);
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

/// MapLibre image id of the direction chevron.
const _arrowImage = 'route-arrow';

/// Screen distance between direction chevrons on the map's route line.
const double _arrowSpacingPx = 70;

/// The chevron PNG is sized for the 3.5dp preview line; the map's line is
/// 4.5dp wide, so its chevrons are scaled up to match.
const double _arrowIconSize = 1.3;

/// Endpoint marker PNGs are sized for the preview; the map's markers read a
/// little larger (they replace the old 7dp + 3dp-ring dots).
const double _endpointIconSize = 1.3;

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
            ColorFilter.mode(AppColors.light.onMap, BlendMode.srcIn));
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

  /// True once every GeoJSON source this style load creates (`route`, plus
  /// `current` or `start`/`end` depending on [LiveMap.fitBounds]) has actually
  /// been added natively. Gates every `updateGeoJsonSource` call so none of
  /// them can race [_onStyleLoaded]'s sequential, awaited source-creation —
  /// `_style` is assigned before any source exists, so a GPS-driven
  /// `didUpdateWidget` landing in that window would otherwise call
  /// `updateGeoJsonSource` on a source id the native style doesn't have yet.
  /// On Android that's a force-unwrapped native lookup with no existence
  /// check (`StyleControllerAndroid.updateGeoJsonSource`), so a miss doesn't
  /// throw a catchable Dart exception — it's a native crash.
  bool _sourcesReady = false;

  /// True once the style has loaded and the camera has centered, at which point
  /// the terrain placeholder crossfades out to reveal the positioned map. Stays
  /// true after the first reveal so a later brightness reload doesn't re-flash
  /// the placeholder.
  bool _styleReady = false;

  /// Centre target: the current fix if any, else the last recorded point.
  Geographic get _centerPosition {
    final c = widget.current ??
        (widget.points.isNotEmpty ? widget.points.last : null);
    return c != null
        ? Geographic(lon: c.lng, lat: c.lat)
        : Geographic(lon: 0, lat: 0);
  }

  @override
  void didUpdateWidget(LiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Push live geometry updates into the existing sources (no style reload).
    // The live map has no start/end dots (only the current marker), and the
    // detail map's points are fixed — so only the route + current need
    // updating. Gated on _sourcesReady: a GPS-driven update can otherwise
    // land before _onStyleLoaded has finished creating these sources — see
    // _sourcesReady's doc comment for why that's a native crash, not just a
    // no-op.
    if (_sourcesReady && widget.points != oldWidget.points) {
      _pushRoute();
    }
    if (_sourcesReady &&
        !widget.fitBounds &&
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

  /// Pushes [LiveMap.points] into the `route` source. Shared by
  /// [didUpdateWidget] and [_onStyleLoaded]'s catch-up push, both gated on
  /// [_sourcesReady].
  void _pushRoute() => _style?.updateGeoJsonSource(
      id: 'route', data: routeLineGeoJson(widget.points));

  /// Moves the `current` marker to [next]: a glide from where it is drawn now,
  /// or a direct snap when there is no previous position, or the jump is big
  /// enough (GPS recovery) that a 600 ms slide would look wrong.
  void _glideMarkerTo(RoutePoint next) {
    // Defense in depth: every call site already checks _sourcesReady, but
    // guard here too so a future call site can't reintroduce the race this
    // gate exists to close (see _sourcesReady's doc comment).
    if (!_sourcesReady) return;
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
    if (!_sourcesReady) return; // see _glideMarkerTo's matching guard
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
    _sourcesReady = false;
    _markerImages.clear();
    final colors = context.colors;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final halo = _hex(colors.routeLineHalo);
    final blue = _hex(colors.routeLineBlue);

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
    // Direction chevrons, placed and rotated along the line by MapLibre.
    await style.addImage(
        _arrowImage, await routeArrowImagePng(colors, pixelRatio));
    await style.addLayer(SymbolStyleLayer(
      id: 'route-arrows',
      sourceId: 'route',
      layout: const {
        'symbol-placement': 'line',
        'symbol-spacing': _arrowSpacingPx,
        'icon-image': _arrowImage,
        'icon-size': _arrowIconSize,
        'icon-rotation-alignment': 'map',
        'icon-keep-upright': false,
        'icon-allow-overlap': true,
        'icon-ignore-placement': true,
      },
    ));

    // Marker mode mirrors the two original composables: the detail / fullscreen
    // map (fitBounds) draws the start ring + finish flag (or the combined loop
    // marker) and NO current marker; the live / active-ride map draws ONLY
    // the current-position marker.
    if (widget.fitBounds) {
      final points = widget.points;
      switch (routeEndpointStyle(points)) {
        case RouteEndpointStyle.none:
          break;
        case RouteEndpointStyle.startOnly:
          await _addEndpointMarker(style, 'start', points.first,
              RouteMarkerImage.start, colors, pixelRatio);
        case RouteEndpointStyle.open:
          await _addEndpointMarker(style, 'start', points.first,
              RouteMarkerImage.start, colors, pixelRatio);
          await _addEndpointMarker(style, 'end', points.last,
              RouteMarkerImage.finish, colors, pixelRatio);
        case RouteEndpointStyle.loop:
          await _addEndpointMarker(style, 'start', points.first,
              RouteMarkerImage.loop, colors, pixelRatio);
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

    _sourcesReady = true;
    // A fresh points/current prop may have arrived via didUpdateWidget while
    // the awaited addSource/addLayer calls above were still in flight — that
    // update was silently dropped by the _sourcesReady gate below (the
    // sources didn't exist yet to receive it). Catch up now that they do,
    // instead of waiting for the next GPS fix to self-heal it.
    _pushRoute();
    if (!widget.fitBounds && widget.current != null) {
      _glideMarkerTo(widget.current!);
    }

    if (widget.fitBounds && widget.points.isNotEmpty) {
      // Awaited (not fire-and-forget like the live map's moves below) so this
      // finishes — hidden behind the terrain placeholder — before the reveal
      // check runs: the map used to appear already visible and then visibly
      // animate/zoom into its fitted framing on every open. A short duration
      // just keeps that hidden wait brief; it's never seen either way.
      try {
        await _controller?.fitBounds(
          bounds: routeBounds(widget.points)!,
          padding: const EdgeInsets.all(24),
          nativeDuration: const Duration(milliseconds: 300),
        );
        // fitBounds() has no zoom ceiling — a short/near-stationary route's
        // tiny bounding box can fit at an arbitrarily high, street-level
        // zoom. Cap it at the same zoom the ride-preview thumbnails use, so
        // a short ride doesn't end up zoomed in absurdly close.
        final zoom = _controller?.camera?.zoom;
        if (zoom != null && zoom > maxPreviewZoom) {
          await _controller?.moveCamera(zoom: maxPreviewZoom);
        }
      } catch (_) {
        // A cancelled/aborted fit still reveals the map below — a slightly
        // off camera beats a placeholder stuck on screen forever.
      }
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
          center: Geographic(lon: c.lng, lat: c.lat),
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
  /// A start/finish/loop marker (see route_marker_painter.dart) as a symbol on
  /// its own point source [id].
  Future<void> _addEndpointMarker(
      StyleController style,
      String id,
      RoutePoint at,
      RouteMarkerImage kind,
      AppColors colors,
      double pixelRatio) async {
    final imageId = 'endpoint-${kind.name}';
    await style.addImage(
        imageId, await routeMarkerImagePng(kind, colors, pixelRatio));
    await style.addSource(GeoJsonSource(id: id, data: _pointGeoJson(at)));
    await style.addLayer(SymbolStyleLayer(
      id: '$id-marker',
      sourceId: id,
      layout: {
        'icon-image': imageId,
        'icon-size': _endpointIconSize,
        'icon-allow-overlap': true,
        'icon-ignore-placement': true,
      },
    ));
  }

  Future<void> _addCurrentMarker(
      StyleController style, ActivityType? type, String blue) async {
    final ring = _hex(context.colors.onMap);
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
      ));
    } else {
      await style.addLayer(CircleStyleLayer(
        id: 'current-dot',
        sourceId: 'current',
        paint: {
          'circle-radius': 7.0,
          'circle-color': blue,
          'circle-stroke-width': 3.0,
          'circle-stroke-color': ring,
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
    final blue = _hex(context.colors.routeLineBlue);
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
    final colors = context.colors;
    return Stack(
      fit: StackFit.expand,
      children: [
        MapLibreMap(
          // Rebuild on brightness change to reload topo-v2/basic-v2-dark.
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
