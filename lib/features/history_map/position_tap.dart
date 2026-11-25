import 'dart:math' as math;

import '../../domain/distance_calculator.dart';
import '../../domain/heading.dart' show LatLng;

/// A finger's reach around the position dot, in logical pixels: wider than the
/// dot itself, so a tap on it is not missed.
const double _reachPx = 28;

/// Circumference of the Earth at the equator, in metres.
const double _earthCircumferenceM = 40075016.686;

/// MapLibre's world width at zoom 0, in logical pixels.
const double _worldPxAtZoom0 = 512;

/// Whether a map tap at [tap] hits the position dot at [position] when the map
/// is at [zoom] (#135). The reach is a fixed number of pixels, so it covers
/// more ground the further the map is zoomed out.
bool isTapOnPosition(
  LatLng tap,
  LatLng position, {
  required double zoom,
  DistanceCalculator distance = const HaversineDistanceCalculator(),
}) {
  final metresPerPx =
      _earthCircumferenceM *
      math.cos(position.lat * math.pi / 180) /
      (_worldPxAtZoom0 * math.pow(2, zoom));
  final away = distance.distanceBetween(
    position.lat,
    position.lng,
    tap.lat,
    tap.lng,
  );
  return away <= _reachPx * metresPerPx;
}
