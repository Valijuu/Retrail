import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:maplibre/maplibre.dart';

import '../core/theme/app_colors.dart';
import '../domain/activity_type.dart';
import '../domain/distance_calculator.dart';
import '../domain/heading.dart'
    show HeadingState, nextHeading, splitRouteTail;
import '../domain/route_progress.dart' show RouteTrack;
import '../l10n/app_localizations.dart';
import '../features/onboarding/activity_type_ui.dart';
import 'openfreemap.dart';
import '../domain/route_markers.dart';
import 'preview_projection.dart';
import 'route_camera.dart';
import 'route_marker_painter.dart';
import 'route_sketch.dart';
import '../core/theme/theme_context.dart';

/// What the camera should do on a [LiveMap] update. Pure, so the follow /
/// recenter rules are unit-tested without pumping the map.
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

/// How long an animated follow / recenter camera move takes.
const Duration _followAnimationDuration = Duration(milliseconds: 600);

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

/// The live map's MapLibre style (Spec 19 §A): OpenFreeMap Liberty by URL in
/// light mode, the bundled Retrail Dark asset in dark mode. MapLibre loads an
/// asset path itself, asynchronously like a URL — not a JSON string, which it
/// applies synchronously before `onMapCreated`, whose reset then discards it.
String liveMapStyle(bool dark) => dark ? kRetrailDarkStyleAsset : kLibertyStyleUrl;

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

/// Opacity of the reference route being followed (Spec 17): clearly behind
/// the live line, still readable on both basemaps.
const double kReferenceRouteOpacity = 0.45;

/// GeoJSON for the ridden parts of a followed reference: one MultiLineString
/// of the [segments] with at least two points (a LineString needs two), or
/// the empty document when none has.
String _multiLineGeoJson(List<List<RoutePoint>> segments) {
  final lines = [
    for (final s in segments)
      if (s.length >= 2) [for (final p in s) [p.lng, p.lat]],
  ];
  if (lines.isEmpty) return _emptyGeoJson;
  return jsonEncode({
    'type': 'Feature',
    'geometry': {'type': 'MultiLineString', 'coordinates': lines},
    'properties': <String, Object?>{},
  });
}

/// GeoJSON for the followed reference (Spec 18): the whole [track] as
/// [ahead] (the line with arrows) and the ridden parts [done] (up to two on a
/// loop ridden across its start/finish; null = nothing ridden yet), greyed on
/// top of it.
({String done, String ahead}) referenceGeoJson(
        RouteTrack track, List<List<RoutePoint>>? done) =>
    (
      done: _multiLineGeoJson(done ?? const []),
      ahead: routeLineGeoJson(track.points),
    );

/// What a reference update pushes: the ridden parts ([done]) always, the
/// whole line ([ahead]) only when [track] is not the one [lastPushed] into
/// the existing sources (a flip), else null — so a fix that only grows the
/// ridden part doesn't re-encode and re-upload the whole route.
({String done, String? ahead}) referenceUpdateGeoJson(
  RouteTrack track,
  List<List<RoutePoint>>? done, {
  required RouteTrack? lastPushed,
}) =>
    (
      done: _multiLineGeoJson(done ?? const []),
      ahead: identical(track, lastPushed)
          ? null
          : routeLineGeoJson(track.points),
    );

/// Where the followed reference's markers go for the endpoint [style] drawn
/// at style load: the start (or combined loop) marker on the first of
/// [points], the finish on the last — only for an [RouteEndpointStyle.open]
/// route. [points] must not be empty (a [RouteEndpointStyle.none] route has
/// no markers to move). After a flip [points] is the reversed route, so both
/// markers swap ends.
({RoutePoint start, RoutePoint? end}) referenceMarkerPoints(
        RouteEndpointStyle style, List<RoutePoint> points) =>
    (
      start: points.first,
      end: style == RouteEndpointStyle.open ? points.last : null,
    );

/// Which reference to push into the `reference` sources, or null to push
/// nothing. [drawn] is the reference whose sources the current style load
/// created (null = none exist, so any push would hit a missing source — a
/// native crash on Android, see `_sourcesReady`); [current] is the widget's
/// reference now. A replaced reference (a flip) redraws the existing sources;
/// one that went away pushes nothing (the screen is leaving).
RouteTrack? referencePushTarget({
  required RouteTrack? drawn,
  required RouteTrack? current,
}) =>
    drawn == null ? null : current;

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

/// MapLibre image id of the direction arrowhead.
const _arrowImage = 'route-arrow';

/// Screen distance between direction arrowheads on the map's route line.
const double _arrowSpacingPx = 60;

/// The arrowhead PNG is sized for the 3.5dp preview line; the map's line is
/// 4.5dp wide, so its arrowheads scale by the same ratio.
const double _arrowIconSize = 4.5 / 3.5;


/// `icon-size` for a symbol image rasterised at [pixelRatio]: MapLibre sizes
/// a registered image by its raw pixel count in dp (see the 0.19 note on the
/// activity badge), so a dp-sized image drawn at the device pixel ratio is
/// scaled back down by it — crisp, at its intended dp size × [scale].
double _iconSize(double scale, double pixelRatio) => scale / pixelRatio;

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
/// Distance of the round map controls (compass, recenter) from the map edge.
const double kMapControlInset = 12.0;

/// Diameter of the round map controls (a small FAB / the compass face).
const double kMapControlSize = 40.0;

const double kLiveMapMinZoom = 3.0;
const double kLiveMapMaxZoom = 19.0;

/// Live/active-ride map: a native MapLibre vector basemap (topo-v2 / basic-v2-dark)
/// with the halo + blue route line and start/end + current-position dots drawn as
/// GeoJSON source layers. The camera follows the current position.
///
/// While following, the camera is heading-up (rotated to the travel
/// direction); the line's tip follows the gliding marker via a `route-tail`
/// segment. Follow feel is tuned/verified on-device.
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

  /// Where the marker is currently drawn (the glide's moving position). A fix
  /// arriving mid-glide first lands the marker on the previous target (a small
  /// hop forward, see [_landGlide]) — otherwise the line, which already runs
  /// to that target, would sit ahead of the marker for the rest of the glide.
  RoutePoint? _renderedCurrent;
  RoutePoint? _glideFrom;
  RoutePoint? _glideTo;

  /// Last time a glide frame was pushed to the source, for throttling the
  /// platform-channel updates to ~25 fps instead of display rate.
  int _lastGlidePushMs = 0;

  /// Where the live line's `route-tail` segment starts (see [splitRouteTail]):
  /// the route source stops one fix short and the tail runs from here to the
  /// gliding marker, so the line's tip follows the marker instead of leading
  /// it. Null when there is no tail to draw.
  RoutePoint? _tailStart;

  /// Heading-up follow: the travel direction the camera turns to, advanced by
  /// [nextHeading] from RECORDED points only (already GPS-filtered — the seed
  /// fix and rejected outliers never rotate the map). Its bearing is null
  /// until the rider has really moved.
  HeadingState _heading = (anchor: null, bearing: null);

  /// The `points` list last pushed into the `route` source, so a fix that
  /// adds no point only redraws the short tail, not the whole line.
  List<RoutePoint>? _pushedPoints;

  /// The reference whose `reference` / `reference-done` sources this style
  /// load created, or null when it created none (see [referencePushTarget]).
  RouteTrack? _drawnReference;

  /// The reference whose whole line the `reference` source holds now (its
  /// lifecycle is [_drawnReference]'s), so a fix that only grows the ridden
  /// part doesn't push the whole line again.
  RouteTrack? _lastPushedReference;

  /// The `ref-start` / `ref-end` marker sources this style load created: the
  /// endpoint [RouteEndpointStyle] drawn then (which marker sources exist)
  /// and the reference whose endpoints they show now. Null when it created
  /// none — then a flip moves nothing (a push would hit a missing source).
  ({RouteEndpointStyle style, RouteTrack shows})? _drawnReferenceMarkers;

  @override
  void initState() {
    super.initState();
    _glide = AnimationController(
      vsync: this,
      duration: _followAnimationDuration,
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

  /// Centre target: the current fix if any, else the last recorded point.
  Geographic get _centerPosition {
    final c = widget.current ??
        (widget.points.isNotEmpty ? widget.points.last : null);
    return c != null
        ? Geographic(lon: c.lng, lat: c.lat)
        : Geographic(lon: 0, lat: 0);
  }

  /// True while the detail map is being re-framed for a new size (dialog ↔
  /// fullscreen): the placeholder sketch — already at the new framing —
  /// covers the native view's resize and camera jump, then fades out.
  bool _resizeCovered = false;

  /// The map's laid-out size, captured in [build] so the detail map can fit
  /// the route to the real viewport (see [_fitCamera]).
  Size _viewportSize = Size.zero;

  /// The whole-route framing for the read-only detail / fullscreen map, or
  /// null before layout / for an empty route.
  RouteCamera? get _fitCamera => _viewportSize.isEmpty
      ? null
      : fitRouteCamera(widget.points,
          width: _viewportSize.width, height: _viewportSize.height);

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
    if (_sourcesReady && !widget.fitBounds && currentChanged) _landGlide();
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
      // No fix and no route yet: the camera still sits at the (0,0) init
      // center — the very first ride, before any position was ever known.
      hadCurrent: oldWidget.current != null || oldWidget.points.isNotEmpty,
      currentChanged: currentChanged,
    );
    if (decision == null) return;
    if (decision.instant) {
      // Jump, don't fly: iOS flies (0,0)→rider zoomed far out and reports that
      // mid-flight zoom, which the next passive follow would then keep.
      _ignoreCancel(_jumpCamera(
        center: _centerPosition,
        zoom: widget.initialZoom,
        bearing: _heading.bearing ?? 0,
      ));
    } else {
      _ignoreCancel(_controller?.animateCamera(
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
        nativeDuration: _followAnimationDuration,
      ));
    }
  }

  /// Ends an in-flight glide at its target before the next one starts, so the
  /// marker is never behind the point the line already reaches.
  void _landGlide() {
    final target = _glideTo;
    if (!_glide.isAnimating || target == null) return;
    _glide.stop();
    _renderedCurrent = target;
    _style?.updateGeoJsonSource(id: 'current', data: _pointGeoJson(target));
  }

  /// Pushes [LiveMap.points] into the `route` source. Shared by
  /// [didUpdateWidget] and [_onStyleLoaded]'s catch-up push, both gated on
  /// [_sourcesReady]. The live map holds the newest fix back for the
  /// `route-tail` segment, which [_pushTail] keeps attached to the marker.
  void _pushRoute() {
    if (widget.fitBounds) {
      _style?.updateGeoJsonSource(
          id: 'route', data: routeLineGeoJson(widget.points));
      return;
    }
    final split = splitRouteTail(widget.points, widget.current);
    if (!identical(widget.points, _pushedPoints) ||
        split.tailStart != _tailStart) {
      _pushedPoints = widget.points;
      _tailStart = split.tailStart;
      _style?.updateGeoJsonSource(
          id: 'route', data: routeLineGeoJson(split.body));
    }
    _pushTail(_renderedCurrent);
  }

  /// Redraws the reference line and its ridden parts, and — when the
  /// reference was replaced (a flip) — moves its start/finish markers. Callers
  /// gate on [_sourcesReady] (see its doc comment); [referencePushTarget]
  /// additionally skips it when this style load created no reference sources.
  void _pushReference() {
    final reference = referencePushTarget(
        drawn: _drawnReference, current: widget.reference);
    if (reference == null) return;
    final g = referenceUpdateGeoJson(reference, widget.referenceDone,
        lastPushed: _lastPushedReference);
    final ahead = g.ahead;
    if (ahead != null) {
      _style?.updateGeoJsonSource(id: 'reference', data: ahead);
      _lastPushedReference = reference;
    }
    _style?.updateGeoJsonSource(id: 'reference-done', data: g.done);
    _pushReferenceMarkers(reference);
  }

  /// Moves the `ref-start` / `ref-end` points to [reference]'s ends, only
  /// those marker sources this style load created ([_drawnReferenceMarkers])
  /// and only when they show another reference (a flip, possibly one that
  /// landed while the style was loading).
  void _pushReferenceMarkers(RouteTrack reference) {
    final drawn = _drawnReferenceMarkers;
    if (drawn == null ||
        identical(drawn.shows, reference) ||
        reference.points.isEmpty) {
      return;
    }
    _drawnReferenceMarkers = (style: drawn.style, shows: reference);
    final m = referenceMarkerPoints(drawn.style, reference.points);
    _style?.updateGeoJsonSource(id: 'ref-start', data: _pointGeoJson(m.start));
    final end = m.end;
    if (end != null) {
      _style?.updateGeoJsonSource(id: 'ref-end', data: _pointGeoJson(end));
    }
  }

  /// Draws the `route-tail` segment from [_tailStart] to [tip] (the marker's
  /// drawn position), or clears it when there is no tail.
  void _pushTail(RoutePoint? tip) {
    final start = _tailStart;
    _style?.updateGeoJsonSource(
      id: 'route-tail',
      data: start != null && tip != null
          ? routeLineGeoJson([start, tip])
          : _emptyGeoJson,
    );
  }

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
      _pushTail(next);
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
    _pushTail(p);
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
  /// (`_sourcesReady`, `_markerReady`, `_drawnReference`,
  /// `_lastPushedReference`, `_drawnReferenceMarkers`, `_styleReady`)
  /// against the new style before its sources exist.
  bool _superseded(StyleController style) =>
      !mounted || !identical(_style, style);

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
    _pushedPoints = null; // the fresh style's `route` source starts over
    _drawnReference = null; // nor has it any reference sources yet
    _lastPushedReference = null;
    _drawnReferenceMarkers = null;
    _markerImages.clear();
    final colors = context.colors;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final halo = _hex(colors.routeLineHalo);
    final blue = _hex(colors.routeLineBlue);

    // The followed reference (Spec 17) goes in first, so every live layer
    // added below draws on top of it.
    final reference = widget.reference;
    if (reference != null) {
      final g = referenceGeoJson(reference, widget.referenceDone);
      await style.addSource(GeoJsonSource(id: 'reference', data: g.ahead));
      if (_superseded(style)) return;
      await style.addSource(GeoJsonSource(id: 'reference-done', data: g.done));
      if (_superseded(style)) return;
      _drawnReference = reference;
      _lastPushedReference = reference;
      await style.addLayer(LineStyleLayer(
        id: 'reference-halo',
        sourceId: 'reference',
        layout: const {'line-cap': 'round', 'line-join': 'round'},
        paint: {
          'line-color': halo,
          'line-width': 8.0,
          'line-opacity': kReferenceRouteOpacity,
        },
      ));
      if (_superseded(style)) return;
      await style.addLayer(LineStyleLayer(
        id: 'reference-line',
        sourceId: 'reference',
        layout: const {'line-cap': 'round', 'line-join': 'round'},
        paint: {
          'line-color': blue,
          'line-width': 4.5,
          'line-opacity': kReferenceRouteOpacity,
        },
      ));
      if (_superseded(style)) return;
      // The ridden parts on top of the whole reference line (Spec 18), still
      // below every live layer added next.
      await style.addLayer(LineStyleLayer(
        id: 'reference-done-line',
        sourceId: 'reference-done',
        layout: const {'line-cap': 'round', 'line-join': 'round'},
        paint: {
          'line-color': _hex(colors.onSurfaceVariant),
          'line-width': 4.5,
          'line-opacity': kReferenceRouteOpacity,
        },
      ));
      if (_superseded(style)) return;
    }

    await style.addSource(
        GeoJsonSource(id: 'route', data: routeLineGeoJson(widget.points)));
    if (_superseded(style)) return;
    await style.addLayer(LineStyleLayer(
      id: 'route-halo',
      sourceId: 'route',
      layout: const {'line-cap': 'round', 'line-join': 'round'},
      paint: {'line-color': halo, 'line-width': 8.0},
    ));
    if (_superseded(style)) return;
    await style.addLayer(LineStyleLayer(
      id: 'route-line',
      sourceId: 'route',
      layout: const {'line-cap': 'round', 'line-join': 'round'},
      paint: {'line-color': blue, 'line-width': 4.5},
    ));
    if (_superseded(style)) return;
    // Direction arrowheads, placed and rotated along the line by MapLibre.
    final arrowPng = await routeArrowImagePng(colors, pixelRatio);
    if (_superseded(style)) return;
    await style.addImage(_arrowImage, arrowPng);
    if (_superseded(style)) return;
    await style.addLayer(SymbolStyleLayer(
      id: 'route-arrows',
      sourceId: 'route',
      layout: {
        'symbol-placement': 'line',
        'symbol-spacing': _arrowSpacingPx,
        'icon-image': _arrowImage,
        'icon-size': _iconSize(_arrowIconSize, pixelRatio),
        'icon-rotation-alignment': 'map',
        'icon-keep-upright': false,
        'icon-allow-overlap': true,
        'icon-ignore-placement': true,
      },
    ));
    if (_superseded(style)) return;
    if (reference != null) {
      // The reference's own arrowheads reuse the image registered just above
      // (a second addImage of the same id throws), below the live route.
      await style.addLayer(
        SymbolStyleLayer(
          id: 'reference-arrows',
          sourceId: 'reference',
          layout: {
            'symbol-placement': 'line',
            'symbol-spacing': _arrowSpacingPx,
            'icon-image': _arrowImage,
            'icon-size': _iconSize(_arrowIconSize, pixelRatio),
            'icon-rotation-alignment': 'map',
            'icon-keep-upright': false,
            'icon-allow-overlap': true,
            'icon-ignore-placement': true,
          },
          paint: const {'icon-opacity': kReferenceRouteOpacity},
        ),
        belowLayerId: 'route-halo',
      );
      if (_superseded(style)) return;
    }
    if (!widget.fitBounds) {
      // The live line's last stretch, drawn up to the gliding marker (see
      // _pushTail) in the route's own halo + blue.
      await style.addSource(
          const GeoJsonSource(id: 'route-tail', data: _emptyGeoJson));
      if (_superseded(style)) return;
      // Halo BELOW the route's blue line: on top, its wider white cap would
      // cut a white crescent into the blue where body and tail meet.
      await style.addLayer(
        LineStyleLayer(
          id: 'route-tail-halo',
          sourceId: 'route-tail',
          layout: const {'line-cap': 'round', 'line-join': 'round'},
          paint: {'line-color': halo, 'line-width': 8.0},
        ),
        belowLayerId: 'route-line',
      );
      if (_superseded(style)) return;
      await style.addLayer(LineStyleLayer(
        id: 'route-tail-line',
        sourceId: 'route-tail',
        layout: const {'line-cap': 'round', 'line-join': 'round'},
        paint: {'line-color': blue, 'line-width': 4.5},
      ));
      if (_superseded(style)) return;
    }

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
          if (_superseded(style)) return;
        case RouteEndpointStyle.open:
          await _addEndpointMarker(style, 'start', points.first,
              RouteMarkerImage.start, colors, pixelRatio);
          if (_superseded(style)) return;
          await _addEndpointMarker(style, 'end', points.last,
              RouteMarkerImage.finish, colors, pixelRatio);
          if (_superseded(style)) return;
        case RouteEndpointStyle.loop:
          await _addEndpointMarker(style, 'start', points.first,
              RouteMarkerImage.loop, colors, pixelRatio);
          if (_superseded(style)) return;
      }
    } else {
      // The followed reference's start/finish (or loop) marker, added before
      // the current-position marker so that one stays on top.
      if (reference != null) {
        final rp = reference.points;
        final drawnStyle = routeEndpointStyle(rp);
        switch (drawnStyle) {
          case RouteEndpointStyle.none:
            break;
          case RouteEndpointStyle.startOnly:
            await _addEndpointMarker(style, 'ref-start', rp.first,
                RouteMarkerImage.start, colors, pixelRatio);
            if (_superseded(style)) return;
          case RouteEndpointStyle.open:
            await _addEndpointMarker(style, 'ref-start', rp.first,
                RouteMarkerImage.start, colors, pixelRatio);
            if (_superseded(style)) return;
            await _addEndpointMarker(style, 'ref-end', rp.last,
                RouteMarkerImage.finish, colors, pixelRatio);
            if (_superseded(style)) return;
          case RouteEndpointStyle.loop:
            await _addEndpointMarker(style, 'ref-start', rp.first,
                RouteMarkerImage.loop, colors, pixelRatio);
            if (_superseded(style)) return;
        }
        // Only now do the marker sources exist; a flip moves them from here
        // on (see _pushReferenceMarkers).
        if (drawnStyle != RouteEndpointStyle.none) {
          _drawnReferenceMarkers = (style: drawnStyle, shows: reference);
        }
      }
      // Current-position marker, updated per fix via updateGeoJsonSource (see
      // didUpdateWidget). Seeded empty until there is a fix.
      final cur = widget.current;
      _renderedCurrent = cur; // glide baseline = the seeded marker position
      await style.addSource(GeoJsonSource(
        id: 'current',
        data: cur != null ? _pointGeoJson(cur) : _emptyGeoJson,
      ));
      if (_superseded(style)) return;
      final markerType = widget.activityType;
      await _addCurrentMarker(style, markerType, blue);
      if (_superseded(style)) return;
      _markerReady = true;
      // An activity change landing while the badge rendered was skipped by
      // didUpdateWidget's _markerReady gate — catch up now.
      if (widget.activityType != markerType) {
        await _swapCurrentMarker();
        if (_superseded(style)) return;
      }
    }

    _sourcesReady = true;
    // A fresh points/current prop may have arrived via didUpdateWidget while
    // the awaited addSource/addLayer calls above were still in flight — that
    // update was silently dropped by the _sourcesReady gate below (the
    // sources didn't exist yet to receive it). Catch up now that they do,
    // instead of waiting for the next GPS fix to self-heal it.
    _pushRoute();
    _pushReference();
    if (!widget.fitBounds && widget.current != null) {
      _glideMarkerTo(widget.current!);
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
      if (_superseded(style)) return;
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
        _ignoreCancel(_jumpCamera(
          center: Geographic(lon: c.lng, lat: c.lat),
          zoom: widget.initialZoom,
          bearing: _heading.bearing,
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
    final png = await routeMarkerImagePng(kind, colors, pixelRatio);
    if (_superseded(style)) return;
    await style.addImage(imageId, png);
    if (_superseded(style)) return;
    await style.addSource(GeoJsonSource(id: id, data: _pointGeoJson(at)));
    if (_superseded(style)) return;
    await style.addLayer(SymbolStyleLayer(
      id: '$id-marker',
      sourceId: id,
      layout: {
        'icon-image': imageId,
        'icon-size': _iconSize(mapEndpointMarkerScale, pixelRatio),
        'icon-allow-overlap': true,
        'icon-ignore-placement': true,
      },
    ));
  }

  /// Adds the live `current-dot` marker layer for [type]: the amber activity
  /// badge (Android `makeIconBitmap` parity) for known types, or the plain blue
  /// dot ([blue]) for null/OTHER. Each badge image is rasterized once.
  Future<void> _addCurrentMarker(
      StyleController style, ActivityType? type, String blue) async {
    final ring = _hex(context.colors.onMap);
    if (rideMarkerIsBadge(type)) {
      final imageId = 'marker-${type!.name}';
      if (_markerImages.add(imageId)) {
        final png = await _activityBadgePng(type);
        if (_superseded(style)) return;
        await style.addImage(imageId, png);
        if (_superseded(style)) return;
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
      if (_superseded(style)) return;
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
    if (_superseded(style)) return;
    await _addCurrentMarker(style, widget.activityType, blue);
  }

  /// The brightness the current native map was built for (see `ValueKey(dark)`
  /// in [build]).
  Brightness? _mapBrightness;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A light/dark switch rebuilds the native map. Cut the old one off NOW,
    // not when the new one reports in: in between, a camera move (the live
    // map's follow on a new fix, the detail map's refit) or a source update
    // would otherwise reach the already disposed map (issue #43).
    final brightness = Theme.of(context).brightness;
    if (_mapBrightness != null && brightness != _mapBrightness) _detachMap();
    _mapBrightness = brightness;
  }

  /// Forgets the native map: no controller, style or sources until the next
  /// map's [MapLibreMap.onMapCreated] / [_onStyleLoaded], and the marker glide
  /// feeding the sources stops.
  void _detachMap() {
    _controller = null;
    _style = null;
    _sourcesReady = false;
    _markerReady = false;
    _drawnReference = null;
    _lastPushedReference = null;
    _drawnReferenceMarkers = null;
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
    final colors = context.colors;
    return LayoutBuilder(builder: (context, constraints) {
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
          ? fitRouteCamera(widget.reference!.points,
              width: size.width, height: size.height)
          : null;
      return Stack(
        fit: StackFit.expand,
        children: [
          MapLibreMap(
            // Rebuild on brightness change to reload topo-v2/basic-v2-dark.
            key: ValueKey(dark),
            options: MapOptions(
              initStyle: liveMapStyle(dark),
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
                          camera: referenceFit)
                      : ColoredBox(color: colors.mapTerrain),
            ),
          ),
        ],
      );
    });
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
