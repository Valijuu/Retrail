import 'package:flutter/animation.dart';
import 'package:maplibre/maplibre.dart';

import '../domain/distance_calculator.dart';
import 'live_map_geojson.dart';
import 'preview_projection.dart';

/// How long an animated follow / recenter camera move takes. The marker glide
/// lasts as long, so the dot and the camera arrive together.
const Duration kFollowAnimationDuration = Duration(milliseconds: 600);

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
    const HaversineDistanceCalculator().distanceBetween(
      from.lat,
      from.lng,
      to.lat,
      to.lng,
    ) >
    _markerSnapThresholdM;

/// Glides the live map's `current` marker between fixes and keeps the live
/// line's `route-tail` segment attached to it.
///
/// The glide is linear, so constant motion between ~1 Hz fixes doesn't pulse;
/// without it the dot teleports while the camera glides. Every push is gated
/// on [sourcesReady]: a source the native style doesn't have yet is a native
/// crash on Android, not a catchable exception.
class MarkerGlide {
  MarkerGlide({
    required TickerProvider vsync,
    required this.style,
    required this.sourcesReady,
  }) : _controller = AnimationController(
         vsync: vsync,
         duration: kFollowAnimationDuration,
       ) {
    _controller.addListener(_onTick);
  }

  /// The style whose sources are updated, or null while no map is attached.
  final StyleController? Function() style;

  /// Whether every source this style load creates exists natively.
  final bool Function() sourcesReady;

  final AnimationController _controller;

  /// Where the marker is currently drawn (the glide's moving position). A fix
  /// arriving mid-glide first lands the marker on the previous target (a small
  /// hop forward, see [land]) — otherwise the line, which already runs to that
  /// target, would sit ahead of the marker for the rest of the glide.
  RoutePoint? _renderedCurrent;
  RoutePoint? _from;
  RoutePoint? _to;

  /// Last time a glide frame was pushed to the source, for throttling the
  /// platform-channel updates to ~25 fps instead of display rate.
  int _lastPushMs = 0;

  /// Where the live line's `route-tail` segment starts (see `splitRouteTail`):
  /// the route source stops one fix short and the tail runs from here to the
  /// gliding marker, so the line's tip follows the marker instead of leading
  /// it. Null when there is no tail to draw.
  RoutePoint? _tailStart;

  /// The tail's start, as set by the route push (see [setTailStart]).
  RoutePoint? get tailStart => _tailStart;

  /// Where the drawn marker is right now (the glide's moving position).
  RoutePoint? get renderedCurrent => _renderedCurrent;

  /// Sets the tail's start. Only the route push ([LiveMapSources.pushRoute])
  /// writes it, so the route source and the tail always agree.
  void setTailStart(RoutePoint? start) => _tailStart = start;

  /// Sets the position the marker is drawn at before any glide: the baseline
  /// a new style load starts from.
  void seedPosition(RoutePoint? position) => _renderedCurrent = position;

  /// Stops the glide and forgets its endpoints (a new style load or a detached
  /// map: its ticks must not touch a `current` source that does not exist).
  void reset() {
    _controller.stop();
    _from = null;
    _to = null;
  }

  /// Stops the glide where it is (the map is detached).
  void stop() => _controller.stop();

  /// Ends an in-flight glide at its target before the next one starts, so the
  /// marker is never behind the point the line already reaches.
  void land() {
    final target = _to;
    if (!_controller.isAnimating || target == null) return;
    _controller.stop();
    _renderedCurrent = target;
    style()?.updateGeoJsonSource(id: 'current', data: pointGeoJson(target));
  }

  /// Moves the `current` marker to [next]: a glide from where it is drawn now,
  /// or a direct snap when there is no previous position, or the jump is big
  /// enough (GPS recovery) that a 600 ms slide would look wrong.
  void moveTo(RoutePoint next) {
    // Defense in depth: every call site already checks the gate, but guard here
    // too so a future call site can't reintroduce the race it closes.
    if (!sourcesReady()) return;
    final from = renderedCurrent;
    if (from == null || markerShouldSnap(from, next)) {
      _controller.stop();
      _renderedCurrent = next;
      style()?.updateGeoJsonSource(id: 'current', data: pointGeoJson(next));
      pushTail(next);
      return;
    }
    _from = from; // mid-glide restart begins at the interpolated position
    _to = next;
    _controller
      ..stop()
      ..forward(from: 0);
  }

  /// Draws the `route-tail` segment from [tailStart] to [tip] (the marker's
  /// drawn position), or clears it when there is no tail.
  void pushTail(RoutePoint? tip) {
    final start = tailStart;
    style()?.updateGeoJsonSource(
      id: 'route-tail',
      data: start != null && tip != null
          ? routeLineGeoJson([start, tip])
          : emptyGeoJson,
    );
  }

  /// Per-frame glide tick: pushes the interpolated position into the `current`
  /// source, throttled to ≥40 ms between pushes (~25 fps) so the platform
  /// channel isn't spammed at display rate. The final frame always lands.
  void _onTick() {
    if (!sourcesReady()) return; // see moveTo's matching guard
    final from = _from, to = _to;
    if (from == null || to == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!_controller.isCompleted && now - _lastPushMs < 40) return;
    _lastPushMs = now;
    final p = lerpPoint(from, to, _controller.value);
    _renderedCurrent = p;
    style()?.updateGeoJsonSource(id: 'current', data: pointGeoJson(p));
    pushTail(p);
  }

  void dispose() => _controller.dispose();
}
