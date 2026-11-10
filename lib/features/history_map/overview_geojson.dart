import 'dart:convert';

import '../../domain/activity_type.dart';
import '../../domain/heat_points.dart';
import '../../domain/heading.dart' show LatLng;
import '../../domain/ride_outline.dart';

/// GeoJSON for the History map overview (#96). Pure functions on encoded
/// outlines, so the whole build can run in a background isolate.

/// Coordinates are written with this many decimals (about 1 m).
const _coordinateDecimals = 5;

String _coordinates(Iterable<LatLng> points) => jsonEncode([
  for (final p in points)
    [
      double.parse(p.lng.toStringAsFixed(_coordinateDecimals)),
      double.parse(p.lat.toStringAsFixed(_coordinateDecimals)),
    ],
]);

/// The line coordinates (`[[lng,lat],…]`) of one encoded outline.
String lineFragment(String polyline) =>
    _coordinates(RideOutline.decode(polyline).points);

/// The heat coordinates (`[[lng,lat],…]`) of one encoded outline.
String heatFragment(String polyline) =>
    _coordinates(HeatPoints.along(RideOutline.decode(polyline)));

String _collection(String type, Iterable<String> fragments) {
  final joined = fragments.join(',');
  if (fragments.isEmpty) return '{"type":"FeatureCollection","features":[]}';
  return '{"type":"FeatureCollection","features":[{"type":"Feature",'
      '"properties":{},"geometry":{"type":"$type",'
      '"coordinates":[$joined]}}]}';
}

/// One MultiLineString feature from [fragments] (one per ride).
String linesGeoJson(Iterable<String> fragments) =>
    _collection('MultiLineString', fragments);

/// One MultiPoint feature from [fragments] (heat points of each ride,
/// joined by dropping each fragment's outer brackets).
String heatGeoJson(Iterable<String> fragments) => _collection('MultiPoint', [
  for (final f in fragments)
    if (f.length > 2) f.substring(1, f.length - 1),
]);

/// A visible ride as the build sees it: plain values only, so it crosses an
/// isolate boundary cheaply.
class OverviewRide {
  const OverviewRide({
    required this.rideId,
    required this.typeId,
    required this.polyline,
    this.lineFragment,
    this.heatFragment,
  });

  final int rideId;
  final String? typeId;
  final String polyline;
  final String? lineFragment;
  final String? heatFragment;
}

/// What the map shows for the visible rides.
class OverviewData {
  const OverviewData({
    required this.linesByType,
    required this.heat,
    required this.newLineFragments,
    required this.newHeatFragments,
  });

  /// Line GeoJSON per activity type id.
  final Map<String, String> linesByType;

  /// Heat GeoJSON of all visible rides.
  final String heat;

  /// Fragments this build computed, to put back into the cache.
  final Map<int, String> newLineFragments;
  final Map<int, String> newHeatFragments;
}

/// Builds the overview data for [rides], reusing cached fragments. Only the
/// part the mode shows is built: the heat points when [heat], else the lines.
OverviewData buildOverviewData(List<OverviewRide> rides, {bool heat = false}) {
  final linesByType = <String, List<String>>{};
  final heatFragments = <String>[];
  final newLines = <int, String>{};
  final newHeat = <int, String>{};
  for (final ride in rides) {
    final type = ActivityType.fromId(ride.typeId)?.id ?? ActivityType.other.id;
    if (heat) {
      heatFragments.add(
        ride.heatFragment ??
            (newHeat[ride.rideId] = heatFragment(ride.polyline)),
      );
    } else {
      (linesByType[type] ??= []).add(
        ride.lineFragment ??
            (newLines[ride.rideId] = lineFragment(ride.polyline)),
      );
    }
  }
  return OverviewData(
    linesByType: {
      for (final e in linesByType.entries) e.key: linesGeoJson(e.value),
    },
    heat: heatGeoJson(heatFragments),
    newLineFragments: newLines,
    newHeatFragments: newHeat,
  );
}
