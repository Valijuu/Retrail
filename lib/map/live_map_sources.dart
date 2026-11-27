import 'package:maplibre/maplibre.dart';

import '../domain/heading.dart' show splitRouteTail;
import '../domain/route_markers.dart';
import '../domain/route_progress.dart' show RouteTrack;
import 'live_map_geojson.dart';
import 'marker_glide.dart';
import 'preview_projection.dart';

/// Pushes the live map's route and reference geometry into the sources a style
/// load created, and remembers what each source shows so a fix only re-uploads
/// what changed. Callers gate every push on the sources being ready (a missing
/// source is a native crash on Android, see `_LiveMapState`).
class LiveMapSources {
  LiveMapSources({required this.style, required this.glide});

  /// The style whose sources are updated, or null while no map is attached.
  final StyleController? Function() style;

  /// The marker glide, which owns the `route-tail` segment.
  final MarkerGlide glide;

  /// The `points` list last pushed into the `route` source, so a fix that
  /// adds no point only redraws the short tail, not the whole line.
  List<RoutePoint>? _pushedPoints;

  /// The reference whose `reference` / `reference-done` sources this style
  /// load created, or null when it created none (see [referencePushTarget]).
  RouteTrack? _drawnReference;

  /// The reference whose whole line the `reference` source holds now (its
  /// lifecycle is [drawnReference]'s), so a fix that only grows the ridden
  /// part doesn't push the whole line again.
  RouteTrack? _lastPushedReference;

  /// The `ref-start` / `ref-end` marker sources this style load created: the
  /// endpoint [RouteEndpointStyle] drawn then (which marker sources exist)
  /// and the reference whose endpoints they show now. Null when it created
  /// none — then a flip moves nothing (a push would hit a missing source).
  ({RouteEndpointStyle style, RouteTrack shows})? _drawnReferenceMarkers;

  /// Records that this style load created the reference sources for
  /// [reference]. Only the style load calls it.
  void referenceDrawn(RouteTrack reference) {
    _drawnReference = reference;
    _lastPushedReference = reference;
  }

  /// Records that this style load created the `ref-start` / `ref-end` sources,
  /// which show [shows]'s endpoints in [style].
  void referenceMarkersDrawn({
    required RouteEndpointStyle style,
    required RouteTrack shows,
  }) {
    _drawnReferenceMarkers = (style: style, shows: shows);
  }

  /// Forgets the reference after the map detached: its sources are gone.
  void detachReference() {
    _drawnReference = null;
    _lastPushedReference = null;
    _drawnReferenceMarkers = null;
  }

  /// Forgets what the (now dead or replaced) style's sources held.
  void reset() {
    _pushedPoints = null;
    detachReference();
  }

  /// Pushes [points] into the `route` source. The live map holds the newest
  /// fix back for the `route-tail` segment, which the glide keeps attached to
  /// the marker; the read-only [fitBounds] map pushes the whole line.
  void pushRoute({
    required List<RoutePoint> points,
    required RoutePoint? current,
    required bool fitBounds,
  }) {
    if (fitBounds) {
      style()?.updateGeoJsonSource(id: 'route', data: routeLineGeoJson(points));
      return;
    }
    final split = splitRouteTail(points, current);
    if (!identical(points, _pushedPoints) ||
        split.tailStart != glide.tailStart) {
      _pushedPoints = points;
      glide.setTailStart(split.tailStart);
      style()?.updateGeoJsonSource(
        id: 'route',
        data: routeLineGeoJson(split.body),
      );
    }
    glide.pushTail(glide.renderedCurrent);
  }

  /// Redraws the reference line and its ridden parts, and — when the
  /// reference was replaced (a flip) — moves its start/finish markers.
  /// [referencePushTarget] skips it when this style load created no reference
  /// sources.
  void pushReference(RouteTrack? current, List<List<RoutePoint>>? done) {
    final reference = referencePushTarget(
      drawn: _drawnReference,
      current: current,
    );
    if (reference == null) return;
    final g = referenceUpdateGeoJson(
      reference,
      done,
      lastPushed: _lastPushedReference,
    );
    final ahead = g.ahead;
    if (ahead != null) {
      style()?.updateGeoJsonSource(id: 'reference', data: ahead);
      _lastPushedReference = reference;
    }
    style()?.updateGeoJsonSource(id: 'reference-done', data: g.done);
    _pushReferenceMarkers(reference);
  }

  /// Moves the `ref-start` / `ref-end` points to [reference]'s ends, only
  /// those marker sources this style load created ([drawnReferenceMarkers])
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
    style()?.updateGeoJsonSource(id: 'ref-start', data: pointGeoJson(m.start));
    final end = m.end;
    if (end != null) {
      style()?.updateGeoJsonSource(id: 'ref-end', data: pointGeoJson(end));
    }
  }
}
