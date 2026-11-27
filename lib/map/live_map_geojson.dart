import 'dart:convert';

import 'package:flutter/material.dart';

import '../domain/route_progress.dart' show RouteTrack;
import '../domain/route_markers.dart';
import 'preview_projection.dart';

/// An empty GeoJSON source payload — a valid document MapLibre accepts when
/// there is nothing to draw yet (a 0/1-point route or an unseeded marker).
const String emptyGeoJson = '{"type":"FeatureCollection","features":[]}';

/// GeoJSON source data for the recorded route (lng,lat order). Pure, so the
/// geometry that feeds the MapLibre source is unit-tested without a map. A
/// LineString needs ≥2 points — MapLibre rejects fewer ("A line string must
/// have two or more coordinate points") — so a 0/1-point route yields the empty
/// document instead.
String routeLineGeoJson(List<RoutePoint> points) {
  if (points.length < 2) return emptyGeoJson;
  return jsonEncode({
    'type': 'Feature',
    'geometry': {
      'type': 'LineString',
      'coordinates': [
        for (final p in points) [p.lng, p.lat],
      ],
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
      if (s.length >= 2)
        [
          for (final p in s) [p.lng, p.lat],
        ],
  ];
  if (lines.isEmpty) return emptyGeoJson;
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
  RouteTrack track,
  List<List<RoutePoint>>? done,
) => (
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
}) => (
  done: _multiLineGeoJson(done ?? const []),
  ahead: identical(track, lastPushed) ? null : routeLineGeoJson(track.points),
);

/// Where the followed reference's markers go for the endpoint [style] drawn
/// at style load: the start (or combined loop) marker on the first of
/// [points], the finish on the last — only for an [RouteEndpointStyle.open]
/// route. [points] must not be empty (a [RouteEndpointStyle.none] route has
/// no markers to move). After a flip [points] is the reversed route, so both
/// markers swap ends.
({RoutePoint start, RoutePoint? end}) referenceMarkerPoints(
  RouteEndpointStyle style,
  List<RoutePoint> points,
) => (
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
}) => drawn == null ? null : current;

String pointGeoJson(RoutePoint p) => jsonEncode({
  'type': 'Feature',
  'geometry': {
    'type': 'Point',
    'coordinates': [p.lng, p.lat],
  },
  'properties': <String, Object?>{},
});

/// `#RRGGBB` for a token [Color], the form MapLibre paint properties expect.
/// `toARGB32()` is the non-deprecated 32-bit accessor (replaces `Color.value`).
String mapHex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
