import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/distance_calculator.dart';
import 'package:retrail/domain/route_markers.dart';

/// Always reports [metres], whatever the coordinates.
class _FixedDistance implements DistanceCalculator {
  const _FixedDistance(this.metres);
  final double metres;
  @override
  double distanceBetween(double lat1, double lon1, double lat2, double lon2) =>
      metres;
}

const _twoPoints = [(lat: 49.45, lng: 11.07), (lat: 49.46, lng: 11.07)];

void main() {
  group('routeEndpointStyle', () {
    test('routeEndpointStyle: no points → none', () {
      expect(routeEndpointStyle(const []), RouteEndpointStyle.none);
    });
    test('routeEndpointStyle: one point → startOnly (standstill ride)', () {
      expect(routeEndpointStyle(const [(lat: 49.45, lng: 11.07)]),
          RouteEndpointStyle.startOnly);
    });
    test('routeEndpointStyle: endpoints ~1 km apart → open', () {
      // 0.009° of latitude ≈ 1 km.
      expect(
          routeEndpointStyle(
              const [(lat: 49.450, lng: 11.07), (lat: 49.459, lng: 11.07)]),
          RouteEndpointStyle.open);
    });
    test('routeEndpointStyle: endpoints ~10 m apart → loop', () {
      // 0.00009° of latitude ≈ 10 m.
      expect(
          routeEndpointStyle(const [
            (lat: 49.45000, lng: 11.07),
            (lat: 49.46000, lng: 11.07),
            (lat: 49.45009, lng: 11.07),
          ]),
          RouteEndpointStyle.loop);
    });
    test('routeEndpointStyle: endpoints exactly 30 m apart (injected calc) → loop (inclusive)', () {
      expect(routeEndpointStyle(_twoPoints, calc: const _FixedDistance(30)),
          RouteEndpointStyle.loop);
    });
    test('routeEndpointStyle: endpoints 30.01 m apart (injected calc) → open', () {
      expect(routeEndpointStyle(_twoPoints, calc: const _FixedDistance(30.01)),
          RouteEndpointStyle.open);
    });
    test('routeEndpointStyle: ride that leaves and returns within 20 m → loop (only the endpoints count)', () {
      // Out ~5 km and back to 0.00018° (≈ 20 m) from the start.
      expect(
          routeEndpointStyle(const [
            (lat: 49.45000, lng: 11.07),
            (lat: 49.47000, lng: 11.10),
            (lat: 49.49000, lng: 11.07),
            (lat: 49.45018, lng: 11.07),
          ]),
          RouteEndpointStyle.loop);
    });
  });

  group('directionArrows', () {
    test('directionArrows: fewer than 2 points → []', () {
      expect(directionArrows(const [(x: 0, y: 0)], spacing: 40, endMargin: 10),
          isEmpty);
    });
    test('directionArrows: line shorter than both end margins (15 px, margin 10) → []', () {
      expect(
          directionArrows(const [(x: 0, y: 0), (x: 15, y: 0)],
              spacing: 40, endMargin: 10),
          isEmpty);
    });
    test('directionArrows: 100 px eastward line, spacing 40, margin 10 → arrows at x 40 and 80, angle 0', () {
      final arrows = directionArrows(const [(x: 0, y: 0), (x: 100, y: 0)],
          spacing: 40, endMargin: 10);
      expect(arrows, [(x: 40.0, y: 0.0, angle: 0.0), (x: 80.0, y: 0.0, angle: 0.0)]);
    });
    test('directionArrows: arrow within the end margin is dropped — 100 px, spacing 46, margin 10 → only x 46 (92 > 100 − 10)', () {
      final arrows = directionArrows(const [(x: 0, y: 0), (x: 100, y: 0)],
          spacing: 46, endMargin: 10);
      expect(arrows, [(x: 46.0, y: 0.0, angle: 0.0)]);
    });
    test('directionArrows: downward line → angle π/2 (canvas y-down)', () {
      final arrows = directionArrows(const [(x: 0, y: 0), (x: 0, y: 100)],
          spacing: 50, endMargin: 10);
      expect(arrows.single.angle, closeTo(math.pi / 2, 1e-9));
      expect(arrows.single.y, 50);
    });
    test("directionArrows: arrow on the second leg of an L-shaped line takes that leg's angle", () {
      // 60 px east, then 60 px south: the arrow at 80 px sits 20 px down leg 2.
      final arrows = directionArrows(
          const [(x: 0, y: 0), (x: 60, y: 0), (x: 60, y: 60)],
          spacing: 80, endMargin: 10);
      expect(arrows.single.x, 60);
      expect(arrows.single.y, closeTo(20, 1e-9));
      expect(arrows.single.angle, closeTo(math.pi / 2, 1e-9));
    });
    test('directionArrows: zero-length segments (duplicate points) are skipped — no NaN angles', () {
      final arrows = directionArrows(const [
        (x: 0, y: 0),
        (x: 40, y: 0),
        (x: 40, y: 0),
        (x: 40, y: 0),
        (x: 100, y: 0),
      ], spacing: 40, endMargin: 10);
      expect(arrows.map((a) => a.x), [40, 80]);
      expect(arrows.every((a) => !a.angle.isNaN), isTrue);
    });
  });
}
