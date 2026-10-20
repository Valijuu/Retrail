import 'dart:math' as math;

import 'package:meta/meta.dart';

import 'ride_stats.dart';

/// Rest of a follow's ride beyond the route, in metres, below which the
/// comparison sheet shows no off-route hint (Spec 20): shorter is GPS noise.
const double minOffRouteHintM = 100;

/// km/h for a speed of one metre per millisecond (1 m/ms = 3.6 km/s).
const double _kmhPerMetrePerMs = 3600;

/// What one row of the History comparison sheet shows (Spec 20).
@immutable
class RouteRowStats {
  const RouteRowStats({
    required this.distanceMetres,
    required this.durationMs,
    required this.avgSpeedKmh,
    this.offRouteMetres,
  });

  /// Distance shown for the row, in metres: the whole ride, or only the
  /// route part of a follow.
  final double distanceMetres;

  /// Time shown for the row in milliseconds: the ride time, or a follow's
  /// time on the route.
  final int durationMs;

  /// [distanceMetres] over [durationMs] in km/h; 0 for a zero time.
  final double avgSpeedKmh;

  /// Metres ridden off the route (the way to it, past the finish). Null on
  /// the original, a follow without route stats, or under
  /// [minOffRouteHintM].
  final double? offRouteMetres;
}

/// Row stats for [ride] on a route of [routeLengthM] metres (Spec 20).
/// With both [coverage] and [routeTimeMs] (a follow) only the route part
/// counts: its share of the route, capped at the ride's distance, over the
/// route time. Without them (the original, or an older follow) the whole
/// ride shows.
RouteRowStats routeRowStats(
  RideStats ride, {
  required double routeLengthM,
  double? coverage,
  int? routeTimeMs,
}) {
  if (coverage == null || routeTimeMs == null) {
    return RouteRowStats(
      distanceMetres: ride.distanceMetres,
      durationMs: ride.durationMs,
      avgSpeedKmh: ride.avgSpeedKmh,
    );
  }
  final onRouteM = math.min(routeLengthM * coverage, ride.distanceMetres);
  final offRouteM = ride.distanceMetres - onRouteM;
  return RouteRowStats(
    distanceMetres: onRouteM,
    durationMs: routeTimeMs,
    avgSpeedKmh: routeTimeMs == 0
        ? 0
        : onRouteM / routeTimeMs * _kmhPerMetrePerMs,
    offRouteMetres: offRouteM < minOffRouteHintM ? null : offRouteM,
  );
}
