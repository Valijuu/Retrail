import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/distance_calculator.dart';
import 'package:retrail/domain/heading.dart' show LatLng;
import 'package:retrail/domain/heat_points.dart';
import 'package:retrail/domain/ride_outline.dart';

const _calc = HaversineDistanceCalculator();

/// One degree of latitude in metres on the Haversine sphere (radius 6371 km).
const _metresPerDegree = 6371000 * math.pi / 180;

/// How far a heat point may lie from its expected place, in metres.
const _toleranceM = 0.01;

/// A point [north] / [east] metres from the origin (0, 0).
LatLng _at(double north, double east) =>
    (lat: north / _metresPerDegree, lng: east / _metresPerDegree);

/// Distance in metres from the origin eastwards along the equator.
double _eastM(LatLng p) => _calc.distanceBetween(0, 0, p.lat, p.lng);

void main() {
  group('HeatPoints.along', () {
    test('an empty outline gives no points', () {
      expect(HeatPoints.along(const RideOutline([]), distance: _calc), isEmpty);
    });

    test('a one-point outline gives no points', () {
      final outline = RideOutline([_at(0, 0)]);
      expect(HeatPoints.along(outline, distance: _calc), isEmpty);
    });

    test('an outline shorter than 30 m gives its first and last point', () {
      final outline = RideOutline([_at(0, 0), _at(0, 10), _at(0, 20)]);
      expect(HeatPoints.along(outline, distance: _calc), [
        _at(0, 0),
        _at(0, 20),
      ]);
    });

    test('a straight 100 m outline: points at 0, 30, 60, 90 and 100 m', () {
      final outline = RideOutline([_at(0, 0), _at(0, 100)]);
      final points = HeatPoints.along(outline, distance: _calc);
      expect(points.map(_eastM).toList(), [
        closeTo(0, _toleranceM),
        closeTo(30, _toleranceM),
        closeTo(60, _toleranceM),
        closeTo(90, _toleranceM),
        closeTo(100, _toleranceM),
      ]);
    });

    test(
      'an outline of exactly 60 m: points at 0, 30 and 60 m, the end once',
      () {
        final outline = RideOutline([_at(0, 0), _at(0, 60)]);
        final points = HeatPoints.along(outline, distance: _calc);
        expect(points.map(_eastM).toList(), [
          closeTo(0, _toleranceM),
          closeTo(30, _toleranceM),
          closeTo(60, _toleranceM),
        ]);
      },
    );

    test('points follow the outline across its corners in ride order', () {
      // 50 m east, then 50 m north: 100 m of arc length with a corner at 50.
      final outline = RideOutline([_at(0, 0), _at(0, 50), _at(50, 50)]);
      final points = HeatPoints.along(outline, distance: _calc);
      expect(points.length, 5);
      expect(_eastM(points[1]), closeTo(30, _toleranceM));
      // 60 m along: 10 m up the northern leg, at the corner's easting.
      expect(points[2].lng, closeTo(_at(0, 50).lng, 1e-9));
      expect(points[2].lat * _metresPerDegree, closeTo(10, _toleranceM));
      expect(points[3].lat * _metresPerDegree, closeTo(40, _toleranceM));
      expect(points.last, _at(50, 50));
    });

    test('two identical points give their first and last point', () {
      final p = _at(3, 3);
      final points = HeatPoints.along(RideOutline([p, p]), distance: _calc);
      expect(points, [p, p]);
    });

    test('a longer ride gets more points', () {
      final short = RideOutline([_at(0, 0), _at(0, 300)]);
      final long = RideOutline([_at(0, 0), _at(0, 3000)]);
      expect(
        HeatPoints.along(long, distance: _calc).length,
        greaterThan(HeatPoints.along(short, distance: _calc).length),
      );
    });

    test('a ride across the antimeridian takes the short arc (#100)', () {
      // About 111 m along the equator from 179.9995 E to 179.9995 W.
      const outline = RideOutline([
        (lat: 0, lng: 179.9995),
        (lat: 0, lng: -179.9995),
      ]);
      final points = HeatPoints.along(outline, distance: _calc);
      expect(points, hasLength(5));
      for (final p in points) {
        expect(p.lng.abs(), greaterThan(179.999));
        expect(p.lng.abs(), lessThanOrEqualTo(180));
      }
      for (var i = 1; i < points.length - 1; i++) {
        final fromStart = _calc.distanceBetween(
          0,
          179.9995,
          points[i].lat,
          points[i].lng,
        );
        expect(fromStart, closeTo(i * HeatPoints.spacingM, _toleranceM));
      }
    });
  });
}
