import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart';

import '../core/theme/app_colors.dart';
import '../domain/activity_type.dart';
import '../domain/heading.dart' show LatLng;
import 'live_map.dart' show symbolRaster;
import 'route_marker_painter.dart' show areaPinImagePng;

/// An empty GeoJSON document MapLibre accepts when there is nothing to draw.
const String emptyOverviewGeoJson =
    '{"type":"FeatureCollection","features":[]}';

/// Source id of the lines of [type]: one source per activity type, never one
/// layer per ride.
String overviewSourceId(ActivityType type) => 'rides-${type.id}';

const String overviewHeatSource = 'heat';
const String overviewHighlightSource = 'highlight';
const String overviewAreaSource = 'area';
const String overviewPositionSource = 'position';
const String overviewPinSource = 'pin';
const String _pinImage = 'area-pin';

/// Ring points of the area circle.
const int _circleSteps = 64;
const double _earthRadiusKm = 6371;
const double _lineWidth = 2.2;
const double _lineOpacity = 0.55;
const double _highlightWidth = 5.0;
const double _highlightHaloWidth = 8.0;
const double _areaFillOpacity = 0.10;
const double _areaLineWidth = 2.0;
const double _positionRadius = 7.0;
const double _positionHaloRadius = 11.0;
const double _heatRadius = 14.0;
const double _heatIntensity = 1.2;
const double _heatOpacity = 0.85;

/// A point as GeoJSON, or the empty document for null.
String overviewPointGeoJson(LatLng? p) => p == null
    ? emptyOverviewGeoJson
    : jsonEncode({
        'type': 'Feature',
        'properties': <String, Object>{},
        'geometry': {
          'type': 'Point',
          'coordinates': [p.lng, p.lat],
        },
      });

/// The circle of [radiusKm] around [pin] as a GeoJSON polygon.
String areaCircleGeoJson(LatLng pin, double radiusKm) {
  final angular = radiusKm / _earthRadiusKm;
  final lat = pin.lat * math.pi / 180;
  final lng = pin.lng * math.pi / 180;
  final ring = <List<double>>[];
  for (var i = 0; i <= _circleSteps; i++) {
    final bearing = 2 * math.pi * i / _circleSteps;
    final pLat = math.asin(
      math.sin(lat) * math.cos(angular) +
          math.cos(lat) * math.sin(angular) * math.cos(bearing),
    );
    final pLng =
        lng +
        math.atan2(
          math.sin(bearing) * math.sin(angular) * math.cos(lat),
          math.cos(angular) - math.sin(lat) * math.sin(pLat),
        );
    ring.add([pLng * 180 / math.pi, pLat * 180 / math.pi]);
  }
  return jsonEncode({
    'type': 'Feature',
    'properties': <String, Object>{},
    'geometry': {
      'type': 'Polygon',
      'coordinates': [ring],
    },
  });
}

/// `#RRGGBB` of [c], the form MapLibre paint properties expect.
String overviewHex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Adds the overview's sources and layers in drawing order, empty. [stale]
/// says the style load was overtaken (#47); the work stops there.
Future<void> addOverviewLayers(
  StyleController style, {
  required AppColors colors,
  required Brightness brightness,
  required double pixelRatio,
  required bool Function() stale,
}) async {
  Future<bool> source(String id) async {
    await style.addSource(GeoJsonSource(id: id, data: emptyOverviewGeoJson));
    return !stale();
  }

  Future<bool> layer(StyleLayer layer) async {
    await style.addLayer(layer);
    return !stale();
  }

  const round = {'line-cap': 'round', 'line-join': 'round'};
  if (!await source(overviewAreaSource)) return;
  if (!await layer(
    FillStyleLayer(
      id: 'area-fill',
      sourceId: overviewAreaSource,
      paint: {
        'fill-color': overviewHex(colors.primary),
        'fill-opacity': _areaFillOpacity,
      },
    ),
  )) {
    return;
  }
  if (!await layer(
    LineStyleLayer(
      id: 'area-line',
      sourceId: overviewAreaSource,
      paint: {
        'line-color': overviewHex(colors.primary),
        'line-width': _areaLineWidth,
      },
    ),
  )) {
    return;
  }
  if (!await source(overviewHeatSource)) return;
  if (!await layer(
    HeatmapStyleLayer(
      id: 'heat-layer',
      sourceId: overviewHeatSource,
      paint: {
        'heatmap-radius': _heatRadius,
        'heatmap-intensity': _heatIntensity,
        'heatmap-opacity': _heatOpacity,
        'heatmap-color': [
          'interpolate',
          ['linear'],
          ['heatmap-density'],
          0,
          'rgba(0,0,0,0)',
          0.15,
          _rgba(colors.primary, 0.25),
          1,
          overviewHex(colors.primary),
        ],
      },
    ),
  )) {
    return;
  }
  for (final type in ActivityType.values) {
    if (!await source(overviewSourceId(type))) return;
    if (!await layer(
      LineStyleLayer(
        id: '${overviewSourceId(type)}-line',
        sourceId: overviewSourceId(type),
        layout: round,
        paint: {
          'line-color': overviewHex(ActivityMapColors.of(type, brightness)),
          'line-width': _lineWidth,
          'line-opacity': _lineOpacity,
        },
      ),
    )) {
      return;
    }
  }
  if (!await source(overviewHighlightSource)) return;
  if (!await layer(
    LineStyleLayer(
      id: 'highlight-halo',
      sourceId: overviewHighlightSource,
      layout: round,
      paint: {
        'line-color': overviewHex(colors.routeLineHalo),
        'line-width': _highlightHaloWidth,
      },
    ),
  )) {
    return;
  }
  if (!await layer(
    LineStyleLayer(
      id: 'highlight-line',
      sourceId: overviewHighlightSource,
      layout: round,
      paint: {
        'line-color': overviewHex(colors.primary),
        'line-width': _highlightWidth,
      },
    ),
  )) {
    return;
  }
  if (!await source(overviewPositionSource)) return;
  if (!await layer(
    CircleStyleLayer(
      id: 'position-halo',
      sourceId: overviewPositionSource,
      paint: {
        'circle-radius': _positionHaloRadius,
        'circle-color': overviewHex(colors.onMap),
      },
    ),
  )) {
    return;
  }
  if (!await layer(
    CircleStyleLayer(
      id: 'position-dot',
      sourceId: overviewPositionSource,
      paint: {
        'circle-radius': _positionRadius,
        'circle-color': overviewHex(colors.routeLineBlue),
      },
    ),
  )) {
    return;
  }
  // The area pin is a symbol of the map itself, on top of everything: it
  // follows the camera without the lag a widget over the map has.
  if (!await source(overviewPinSource)) return;
  final raster = symbolRaster(1, pixelRatio);
  final png = await areaPinImagePng(colors, raster.rasterRatio);
  if (stale()) return;
  await style.addImage(_pinImage, png);
  if (stale()) return;
  await layer(
    SymbolStyleLayer(
      id: 'area-pin',
      sourceId: overviewPinSource,
      layout: {
        'icon-image': _pinImage,
        'icon-size': raster.iconSize,
        'icon-anchor': 'bottom',
        'icon-allow-overlap': true,
        'icon-ignore-placement': true,
      },
    ),
  );
}

String _rgba(Color c, double alpha) =>
    'rgba(${(c.r * 255).round()},${(c.g * 255).round()},${(c.b * 255).round()},$alpha)';
