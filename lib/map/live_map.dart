import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/theme_context.dart';
import '../domain/activity_type.dart';
import '../domain/heading.dart' show HeadingState, nextHeading;
import '../domain/route_markers.dart';
import '../domain/route_progress.dart' show RouteTrack;
import '../l10n/app_localizations.dart';
import 'live_map_layers.dart';
import 'live_map_sources.dart';
import 'map_language.dart';
import 'openfreemap.dart';
import 'marker_glide.dart';
import 'preview_projection.dart';
import 'route_camera.dart';
import 'route_sketch.dart';

// The pure helpers of the live map live in their own files; this one stays the
// import point for the widget and everything tests and screens used from it.
// Names that tests and other screens use; everything else stays internal to
// lib/map (narrowed from a bare export, see #160).
export 'live_map_geojson.dart'
    show
        emptyGeoJson,
        kReferenceRouteOpacity,
        mapHex,
        pointGeoJson,
        referenceGeoJson,
        referenceMarkerPoints,
        referencePushTarget,
        referenceUpdateGeoJson,
        routeLineGeoJson;
export 'live_map_layers.dart'
    show
        activityBadgePngFromLoader,
        arrowIconSize,
        arrowImageId,
        arrowSpacingPx,
        rideMarkerIsBadge,
        symbolRaster;
export 'marker_glide.dart'
    show kFollowAnimationDuration, lerpPoint, markerShouldSnap;

class CameraFollow {
  const CameraFollow({required this.resetBearing, this.instant = false});

  /// True when, with no travel direction measured yet, the move turns the map
  /// north (an explicit recenter tap or the first position arriving); false
  /// keeps the camera's bearing until one is measured (passive follow on a
  /// new fix).
  final bool resetBearing;

  /// True to jump straight to the target instead of animating — only for the
  /// first position, where the camera still sits at the (0,0) init center and
  /// a fly-to would report a mid-flight, zoomed-out camera (iOS) that the next
  /// passive follow then keeps. Always paired with [resetBearing].
  final bool instant;
}

/// Decides whether to move the camera to the current position on a widget
/// update. Every move lands at ride zoom: any zoom gesture drops follow, so
/// while following the zoom only ever changes through these moves (and iOS
/// reports a mid-flight zoom that must not be carried over, #40). Null means
/// leave the camera alone; the first matching rule wins:
/// - **No current position**: never move — there is nothing to center on.
/// - **First position while following** ([hadCurrent] false): jump
///   ([CameraFollow.instant]) to the rider at ride zoom — the map had nothing
///   to keep, and an animated flight from (0,0) would land zoomed out.
/// - **Recenter just pressed** (follow off→on): animate there now, even
///   without a new fix — this makes the recenter button responsive.
/// - **Following + a new fix**: animate to keep the rider centered.
/// - **Not following**: never move (respect the user's pan/zoom) — this also
///   holds for a first position.
CameraFollow? followCameraUpdate({
  required bool wasFollowing,
  required bool isFollowing,
  required bool hasCurrent,
  bool hadCurrent = true,
  required bool currentChanged,
}) {
  if (!hasCurrent) return null;
  final justRecentered = isFollowing && !wasFollowing;
  final firstPosition = isFollowing && !hadCurrent;
  if (firstPosition) {
    return const CameraFollow(resetBearing: true, instant: true);
  }
  if (justRecentered) return const CameraFollow(resetBearing: true);
  if (isFollowing && currentChanged) {
    return const CameraFollow(resetBearing: false);
  }
  return null;
}

/// Interactive-map zoom bounds. Without a floor, you could pinch out without
/// limit to a tiny repeated-world speck that janks the frame and makes the ride
/// controls hard to hit; the ceiling caps it at useful street detail. Low enough
/// that [LiveMap.fitBounds] still frames any realistic ride.
/// Distance of the round map controls (compass, recenter) from the map edge.
const double kMapControlInset = 12.0;

/// Diameter of the round map controls (a small FAB / the compass face).
const double kMapControlSize = 40.0;

const double kLiveMapMinZoom = 3.0;
const double kLiveMapMaxZoom = 19.0;

/// Live/active-ride map: a native MapLibre vector basemap (Retrail Light / Retrail Dark)
/// with the halo + blue route line and start/end + current-position dots drawn as
/// GeoJSON source layers. The camera follows the current position.
///
/// While following, the camera is heading-up (rotated to the travel
/// direction); the line's tip follows the gliding marker via a `route-tail`
/// segment. Follow feel is tuned/verified on-device.
/// The live map's MapLibre style (Spec 19 §A): the bundled Retrail Light /
/// Retrail Dark asset. MapLibre loads an asset path itself, asynchronously like
/// a URL — not a JSON string, which it applies synchronously before
/// `onMapCreated`, whose reset then discards it.
String liveMapStyle(bool dark, String language) =>
    retrailStyleAsset(dark: dark, language: language);

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
    this.compassClearance = 0,
    this.reference,
    this.referenceDone,
    this.headingTrail,
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

  /// Space the compass leaves free below it for controls the screen stacks in
  /// the map's bottom-left corner (the active ride's recenter button), so it
  /// sits directly above them. 0 puts it in the corner itself.
  final double compassClearance;

  /// A saved route being followed (Spec 17), drawn semi-transparent under the
  /// live line with its start/finish markers and arrows. Null = not following
  /// (no reference sources or layers are added at all).
  ///
  /// It is the route as ridden (Spec 18: reversed after a flip), so its
  /// arrows point the riding way and its first point carries the start
  /// marker. The sources are created at style load: a reference that appears
  /// later is drawn from the next style load on, and a replaced one (a flip)
  /// redraws the existing line and moves the start/finish markers.
  final RouteTrack? reference;

  /// The ridden parts of [reference] (up to two on a loop ridden across its
  /// start/finish), greyed on top of it. Null or empty = nothing ridden yet.
  final List<List<RoutePoint>>? referenceDone;

  /// Positions the heading-up camera turns by, instead of [points]. The
  /// follow-only screen passes its recent fixes here because it draws no
  /// line of its own.
  final List<RoutePoint>? headingTrail;

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

class _LiveMapState extends State<LiveMap> with SingleTickerProviderStateMixin {
  MapController? _controller;
  StyleController? _style;

  /// The current-position marker's glide and the live line's tail. Created in
  /// [initState]: a lazy `late final` would first run in [dispose], where the
  /// TickerMode ancestor lookup throws on the deactivated element.
  late final MarkerGlide _glide;

  /// Pushes route and reference geometry into this style load's sources.
  late final LiveMapSources _sources;

  /// Adds layers to the loaded style; null until a style has loaded.
  LiveMapLayers? _layers;

  /// Heading-up follow: the travel direction the camera turns to, advanced by
  /// [nextHeading] from RECORDED points only (already GPS-filtered — the seed
  /// fix and rejected outliers never rotate the map). Its bearing is null
  /// until the rider has really moved.
  HeadingState _heading = (anchor: null, bearing: null);

  /// True once the live `current-dot` marker has been added in [_onStyleLoaded]
  /// — gates the live activity-marker swap so it never tries to remove a layer
  /// that the style load hasn't created yet.
  bool _markerReady = false;

  /// True once every GeoJSON source this style load creates (`route`, plus
  /// `route-tail` + `current` or `start`/`end` depending on
  /// [LiveMap.fitBounds], and `reference` + `reference-done` when following a
  /// [LiveMap.reference]) has actually
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

  /// True while the detail map is being re-framed for a new size (dialog ↔
  /// fullscreen): the placeholder sketch — already at the new framing —
  /// covers the native view's resize and camera jump, then fades out.
  bool _resizeCovered = false;

  /// The map's laid-out size, captured in [build] so the detail map can fit
  /// the route to the real viewport (see [_fitCamera]).
  Size _viewportSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _glide = MarkerGlide(
      vsync: this,
      style: () => _style,
      sourcesReady: () => _sourcesReady,
    );
    _sources = LiveMapSources(style: () => _style, glide: _glide);
  }

  /// Centre target: the current fix if any, else the last recorded point.
  Geographic get _centerPosition {
    final c =
        widget.current ??
        (widget.points.isNotEmpty ? widget.points.last : null);
    return c != null
        ? Geographic(lon: c.lng, lat: c.lat)
        : Geographic(lon: 0, lat: 0);
  }

  /// The whole-route framing for the read-only detail / fullscreen map, or
  /// null before layout / for an empty route.
  RouteCamera? get _fitCamera => _viewportSize.isEmpty
      ? null
      : fitRouteCamera(
          widget.points,
          width: _viewportSize.width,
          height: _viewportSize.height,
        );

  void _pushRoute() => _sources.pushRoute(
    points: widget.points,
    current: widget.current,
    fitBounds: widget.fitBounds,
  );

  void _pushReference() =>
      _sources.pushReference(widget.reference, widget.referenceDone);

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
    final currentChanged = widget.current != oldWidget.current;
    if (_sourcesReady && !widget.fitBounds && currentChanged) _glide.land();
    if (_sourcesReady &&
        (widget.points != oldWidget.points ||
            (!widget.fitBounds && currentChanged))) {
      _pushRoute();
    }
    if (_sourcesReady &&
        (!identical(widget.reference, oldWidget.reference) ||
            !identical(widget.referenceDone, oldWidget.referenceDone))) {
      _pushReference();
    }
    final trail = widget.headingTrail ?? widget.points;
    final oldTrail = oldWidget.headingTrail ?? oldWidget.points;
    if (!widget.fitBounds && trail != oldTrail && trail.isNotEmpty) {
      _heading = nextHeading(_heading, trail.last);
    }
    if (_sourcesReady &&
        !widget.fitBounds &&
        widget.current != oldWidget.current &&
        widget.current != null) {
      _glide.moveTo(widget.current!);
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
      // No fix and no route yet: the camera still sits at the (0,0) init
      // center — the very first ride, before any position was ever known.
      hadCurrent: oldWidget.current != null || oldWidget.points.isNotEmpty,
      currentChanged: currentChanged,
    );
    if (decision == null) return;
    if (decision.instant) {
      // Jump, don't fly: iOS flies (0,0)→rider zoomed far out and reports that
      // mid-flight zoom, which the next passive follow would then keep.
      _ignoreCancel(
        _jumpCamera(
          center: _centerPosition,
          zoom: widget.initialZoom,
          bearing: _heading.bearing ?? 0,
        ),
      );
    } else {
      _ignoreCancel(
        _controller?.animateCamera(
          center: _centerPosition,
          // Always ride zoom, never controller.camera.zoom: mid-flight on iOS
          // that is the zoomed-out fly-to arc, which would then stick (#40).
          zoom: widget.initialZoom,
          // Heading-up while following. Null keeps the camera's bearing (the
          // read-only detail map, or no movement measured yet on a passive
          // follow); a recenter before any movement turns the map north.
          bearing: widget.fitBounds
              ? null
              : (decision.resetBearing
                    ? (_heading.bearing ?? 0)
                    : _heading.bearing),
          nativeDuration: kFollowAnimationDuration,
        ),
      );
    }
  }

  /// A camera move can be superseded by the next one (every fix recenters),
  /// which completes the in-flight future with `Exception: Animation cancelled`.
  /// That's expected — attach a handler so it isn't an unhandled exception.
  void _ignoreCancel(Future<void>? future) {
    future?.catchError((Object _) {});
  }

  /// Re-applies the whole-route framing (north-up, like the first one) after
  /// the viewport changed size, then lifts the placeholder that covered the
  /// resize one frame later, once the native view has caught up.
  Future<void> _refit() async {
    final fit = _fitCamera;
    if (!mounted || fit == null) return;
    try {
      await _jumpCamera(
        center: Geographic(lon: fit.lng, lat: fit.lat),
        zoom: fit.zoom,
        bearing: 0,
      );
    } catch (_) {
      // Uncover regardless — a slightly off camera beats a stuck placeholder.
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _resizeCovered = false);
    });
  }

  /// An instant camera jump that lands on [zoom] exactly, on iOS too: there
  /// maplibre's moveCamera applies the zoom at the OLD centre (as an altitude)
  /// before moving, so a jump across latitudes — (0,0) init → rider at 49° N —
  /// came out ~0.6 zoom levels short (issue #41). Moving first and zooming
  /// second sets the zoom at the new centre (the centre is repeated so neither
  /// move relies on unset fields); on Android it is just two moves.
  Future<void> _jumpCamera({
    required Geographic center,
    required double zoom,
    double? bearing,
  }) async {
    final controller = _controller;
    if (controller == null) return;
    await controller.moveCamera(center: center, bearing: bearing);
    await controller.moveCamera(center: center, zoom: zoom);
  }

  /// True when [style]'s load was overtaken (issue #47): the map was detached
  /// (`_style` nulled) or a newer style loaded meanwhile (brightness rebuild).
  /// [_onStyleLoaded] and its helpers check this after every await, so an
  /// old load can't add layers to a dead map or set the ready flags
  /// (`_sourcesReady`, `_markerReady`, `_styleReady`, and the reference
  /// sources of [LiveMapSources])
  /// against the new style before its sources exist.
  bool _superseded(StyleController style) =>
      !mounted || !identical(_style, style);

  Future<void> _onStyleLoaded(StyleController style) async {
    _style = style;
    // A fresh style (e.g. a brightness rebuild) carries none of the previously
    // registered images/layers, so rebuild them from scratch — and stop any
    // in-flight marker glide so its ticks can't touch the `current` source
    // before this load recreates it.
    _glide.reset();
    _markerReady = false;
    _sourcesReady = false;
    _sources.reset(); // the fresh style's sources start over
    bool superseded() => _superseded(style);
    final layers = _layers = LiveMapLayers(
      style: style,
      colors: context.colors,
      pixelRatio: MediaQuery.devicePixelRatioOf(context),
      superseded: superseded,
    );

    // The followed reference (Spec 17) goes in first, so every live layer
    // added below draws on top of it.
    final reference = widget.reference;
    if (reference != null) {
      await layers.addReference(reference, widget.referenceDone);
      if (superseded()) return;
      _sources.referenceDrawn(reference);
    }
    await layers.addRoute(widget.points, reference: reference);
    if (superseded()) return;
    if (!widget.fitBounds) {
      await layers.addTail();
      if (superseded()) return;
    }

    // Marker mode mirrors the two original composables: the detail / fullscreen
    // map (fitBounds) draws the start ring + finish flag (or the combined loop
    // marker) and NO current marker; the live / active-ride map draws ONLY
    // the current-position marker.
    if (widget.fitBounds) {
      await layers.addEndpoints('start', 'end', widget.points);
      if (superseded()) return;
    } else {
      // The followed reference's start/finish (or loop) marker, added before
      // the current-position marker so that one stays on top.
      if (reference != null) {
        final drawnStyle = await layers.addEndpoints(
          'ref-start',
          'ref-end',
          reference.points,
        );
        if (superseded()) return;
        // Only now do the marker sources exist; a flip moves them from here
        // on (see LiveMapSources.pushReference).
        if (drawnStyle != RouteEndpointStyle.none) {
          _sources.referenceMarkersDrawn(style: drawnStyle, shows: reference);
        }
      }
      // Current-position marker, updated per fix via updateGeoJsonSource (see
      // didUpdateWidget). Seeded empty until there is a fix.
      _glide.seedPosition(widget.current); // glide baseline
      final markerType = widget.activityType;
      await layers.addCurrent(widget.current, markerType);
      if (superseded()) return;
      _markerReady = true;
      // An activity change landing while the badge rendered was skipped by
      // didUpdateWidget's _markerReady gate — catch up now.
      if (widget.activityType != markerType) {
        await _swapCurrentMarker();
        if (superseded()) return;
      }
    }

    _sourcesReady = true;
    // A fresh points/current prop may have arrived via didUpdateWidget while
    // the awaited addSource/addLayer calls above were still in flight — that
    // update was silently dropped by the _sourcesReady gate (the sources
    // didn't exist yet to receive it). Catch up now that they do, instead of
    // waiting for the next GPS fix to self-heal it.
    _pushRoute();
    _pushReference();
    if (!widget.fitBounds && widget.current != null) {
      _glide.moveTo(widget.current!);
    }

    final fit = widget.fitBounds ? _fitCamera : null;
    if (fit != null) {
      // Frame the whole route with ONE instant move computed here, not the
      // package's fitBounds(): on iOS that only STARTS an animation and
      // returns, so the zoom-cap moveCamera that used to follow it cancelled
      // the fit mid-flight and left the camera on the route's end (the map's
      // init center). Same framing on both platforms, applied before reveal.
      try {
        await _jumpCamera(
          center: Geographic(lon: fit.lng, lat: fit.lat),
          zoom: fit.zoom,
        );
      } catch (_) {
        // A failed move still reveals the map below — a slightly off camera
        // beats a placeholder stuck on screen forever.
      }
      if (superseded()) return;
    } else if (!widget.fitBounds && widget.isFollowing) {
      // Recenter once the style is ready. The map is created with initCenter
      // (0,0) when the ride starts with no fix yet; the follow update in
      // didUpdateWidget is skipped if the first fix arrives before the
      // controller exists, which would leave the camera stranded at null island
      // (a blank light-blue ocean) even though recording works. Snapping here —
      // when the controller and style are both ready — recovers that race.
      final c =
          widget.current ??
          (widget.points.isNotEmpty ? widget.points.last : null);
      if (c != null) {
        _ignoreCancel(
          _jumpCamera(
            center: Geographic(lon: c.lng, lat: c.lat),
            zoom: widget.initialZoom,
            bearing: _heading.bearing,
          ),
        );
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

  /// Replaces the live `current-dot` marker after [LiveMap.activityType] changes.
  Future<void> _swapCurrentMarker() async {
    final layers = _layers;
    if (layers == null || !mounted) return;
    await layers.swapCurrentMarker(widget.activityType);
  }

  /// The brightness the current native map was built for (see `ValueKey(dark)`
  /// in [build]).
  Brightness? _mapBrightness;

  /// The language the current native map's style was built for (#128).
  String? _mapLanguage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A light/dark switch rebuilds the native map. Cut the old one off NOW,
    // not when the new one reports in: in between, a camera move (the live
    // map's follow on a new fix, the detail map's refit) or a source update
    // would otherwise reach the already disposed map (issue #43).
    final brightness = Theme.of(context).brightness;
    final language = mapLanguageFor(Localizations.localeOf(context));
    if (_mapBrightness != null &&
        (brightness != _mapBrightness || language != _mapLanguage)) {
      _detachMap();
    }
    _mapBrightness = brightness;
    _mapLanguage = language;
  }

  /// Forgets the native map: no controller, style or sources until the next
  /// map's [MapLibreMap.onMapCreated] / [_onStyleLoaded], and the marker glide
  /// feeding the sources stops.
  void _detachMap() {
    _controller = null;
    _style = null;
    _layers = null;
    _sourcesReady = false;
    _markerReady = false;
    _sources.detachReference();
    _glide.stop();
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
    final language = mapLanguageFor(Localizations.localeOf(context));
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        // The detail dialog moves this same map into fullscreen and back (one
        // GlobalKey): re-frame the whole route for the new size once laid out.
        if (widget.fitBounds && _sourcesReady && size != _viewportSize) {
          _resizeCovered = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _refit());
        }
        final covered = !_styleReady || _resizeCovered;
        _viewportSize = size;
        final fit = widget.fitBounds ? _fitCamera : null;
        // While following a saved route, the live map's placeholder already
        // shows that route (framed whole) instead of bare terrain. Computed on
        // every build (not only while covered) so the sketch stays the fading
        // child through the reveal instead of vanishing in one frame.
        final referenceFit = !widget.fitBounds && widget.reference != null
            ? fitRouteCamera(
                widget.reference!.points,
                width: size.width,
                height: size.height,
              )
            : null;
        return Stack(
          fit: StackFit.expand,
          children: [
            MapLibreMap(
              // Rebuild on a brightness or language change to reload the matching
              // style: Retrail Light / Dark, English / German names.
              key: ValueKey((dark, language)),
              options: MapOptions(
                initStyle: liveMapStyle(dark, language),
                // The detail map starts on its whole-route framing already, so
                // even the first native frame shows the full ride.
                initCenter: fit != null
                    ? Geographic(lon: fit.lng, lat: fit.lat)
                    : _centerPosition,
                initZoom: fit?.zoom ?? widget.initialZoom,
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
              onMapCreated: (c) {
                _detachMap(); // the new map's style hasn't loaded yet
                _controller = c;
              },
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
              // Live map only: shown once the map is turned away from north and
              // not following (hand-panned / rotated); a tap turns it back
              // north. While following, the map is heading-up on purpose. The
              // read-only detail / fullscreen map has no compass.
              children: [
                if (!widget.fitBounds && !widget.isFollowing)
                  MapCompass(
                    hideIfRotatedNorth: true,
                    // Bottom-left, stacked above the recenter button: both appear
                    // once the map is moved by hand, and both are in thumb reach.
                    alignment: Alignment.bottomLeft,
                    padding: EdgeInsets.only(
                      left: kMapControlInset,
                      bottom: kMapControlInset + widget.compassClearance,
                    ),
                    child: _CompassButton(colors: colors),
                  ),
              ],
            ),
            // Terrain-colored placeholder over the map until the style has loaded
            // and centered, then crossfade it out — so the reveal is a smooth fade
            // to an already-positioned map instead of a flash of the (0,0) ocean or
            // tiles popping in. Fading a plain widget avoids platform-view opacity
            // quirks; IgnorePointer lets gestures through once revealed.
            IgnorePointer(
              ignoring: !covered,
              child: AnimatedOpacity(
                opacity: covered ? 1.0 : 0.0,
                // Covering is instant (a resize must not show through); only
                // the reveal fades.
                duration: covered
                    ? Duration.zero
                    : const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                // The detail map shows its route as a flat sketch right away —
                // framed exactly like the map it fades into — and keeps it if
                // the style never loads (offline with nothing cached).
                child: fit != null
                    ? RouteSketch(points: widget.points, camera: fit)
                    : referenceFit != null
                    ? RouteSketch(
                        points: widget.reference!.points,
                        camera: referenceFit,
                      )
                    : ColoredBox(color: colors.mapTerrain),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The compass face: an app-token circle with a north-pointing arrow, which
/// [MapCompass] rotates with the camera; tapping it turns the map north.
class _CompassButton extends StatelessWidget {
  const _CompassButton({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: AppLocalizations.of(context).a11yCompassNorth,
      child: Material(
        color: colors.surface,
        shape: const CircleBorder(),
        elevation: 2,
        child: SizedBox.square(
          dimension: kMapControlSize,
          child: Icon(Icons.navigation, color: colors.primary, size: 22),
        ),
      ),
    );
  }
}
