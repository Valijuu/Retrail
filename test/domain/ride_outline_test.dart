import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/distance_calculator.dart';
import 'package:retrail/domain/heading.dart' show LatLng;
import 'package:retrail/domain/ride_outline.dart';

const _calc = HaversineDistanceCalculator();

/// One degree of latitude in metres, close enough for offsets of a few metres.
const _metresPerDegree = 111320.0;

/// A point [north] / [east] metres from the origin (0, 0).
LatLng _at(double north, double east) =>
    (lat: north / _metresPerDegree, lng: east / _metresPerDegree);

/// Points on a straight line from the origin eastwards, [count] of them,
/// [stepM] metres apart.
List<LatLng> _lineEast(int count, double stepM) => [
  for (var i = 0; i < count; i++) _at(0, i * stepM),
];

/// Reports every distance as far beyond the tolerance.
class _FarCalculator implements DistanceCalculator {
  const _FarCalculator();

  @override
  double distanceBetween(double lat1, double lon1, double lat2, double lon2) =>
      1000;
}

void main() {
  group('RideOutline.simplify', () {
    test('no points: empty outline', () {
      final outline = RideOutline.simplify(const [], distance: _calc);
      expect(outline.points, isEmpty);
    });

    test('one point: empty outline', () {
      final outline = RideOutline.simplify([_at(0, 0)], distance: _calc);
      expect(outline.points, isEmpty);
    });

    test('two points stay as they are', () {
      final points = [_at(0, 0), _at(0, 100)];
      final outline = RideOutline.simplify(points, distance: _calc);
      expect(outline.points, points);
    });

    test('three identical points give two points', () {
      final p = _at(10, 10);
      final outline = RideOutline.simplify([p, p, p], distance: _calc);
      expect(outline.points, [p, p]);
    });

    test(
      'straight line with a dense middle: only the first and last point remain',
      () {
        final points = _lineEast(200, 2);
        final outline = RideOutline.simplify(points, distance: _calc);
        expect(outline.points, [points.first, points.last]);
      },
    );

    test('a corner of 30 m stays', () {
      final corner = _at(30, 100);
      // The points before and after the corner lie on its two legs.
      final points = [
        _at(0, 0),
        _at(15, 50),
        corner,
        _at(15, 150),
        _at(0, 200),
      ];
      final outline = RideOutline.simplify(points, distance: _calc);
      expect(outline.points, [points.first, corner, points.last]);
    });

    test('a bump of 4 m is dropped, a bump of 6 m stays (tolerance 5 m)', () {
      final small = [_at(0, 0), _at(4, 50), _at(0, 100)];
      final large = [_at(0, 0), _at(6, 50), _at(0, 100)];
      expect(RideOutline.simplify(small, distance: _calc).points, [
        small.first,
        small.last,
      ]);
      expect(RideOutline.simplify(large, distance: _calc).points, large);
    });

    test('the result never has more points than the input', () {
      final random = math.Random(7);
      final points = [
        for (var i = 0; i < 300; i++)
          _at(random.nextDouble() * 400, random.nextDouble() * 400),
      ];
      final outline = RideOutline.simplify(points, distance: _calc);
      expect(outline.points.length, lessThanOrEqualTo(points.length));
      expect(outline.points.first, points.first);
      expect(outline.points.last, points.last);
    });

    test(
      'a zigzag with 1200 corners of 8 m is capped at 500 points by doubling '
      'the tolerance',
      () {
        // Every corner is 8 m off the straight line: at 5 m all 1200 stay,
        // at 10 m they all go — so the cap leaves the two endpoints.
        final points = [
          for (var i = 0; i < 1200; i++) _at(i.isEven ? 0 : 8, i * 20.0),
        ];
        final outline = RideOutline.simplify(points, distance: _calc);
        expect(outline.points.length, lessThanOrEqualTo(RideOutline.maxPoints));
        expect(outline.points.first, points.first);
        expect(outline.points.last, points.last);
      },
    );

    test('distances come from the injected DistanceCalculator', () {
      // A calculator that calls everything far apart keeps every point.
      final points = _lineEast(10, 1);
      final outline = RideOutline.simplify(
        points,
        distance: const _FarCalculator(),
      );
      expect(outline.points, points);
    });
  });

  group('RideOutline encode and decode', () {
    test('encode then decode: each point within 1 m', () {
      const points = <LatLng>[
        (lat: 48.137154, lng: 11.576124),
        (lat: 48.1385, lng: 11.5733),
        (lat: -33.868820, lng: 151.209290),
        (lat: 0.000004, lng: -0.000004),
      ];
      final decoded = RideOutline.decode(const RideOutline(points).encode());
      expect(decoded.points.length, points.length);
      for (var i = 0; i < points.length; i++) {
        final d = _calc.distanceBetween(
          points[i].lat,
          points[i].lng,
          decoded.points[i].lat,
          decoded.points[i].lng,
        );
        expect(d, lessThan(1), reason: 'point $i');
      }
    });

    test(
      'the encoded polyline uses the standard format with 5 decimal places',
      () {
        // The reference example of the polyline algorithm format.
        const points = <LatLng>[
          (lat: 38.5, lng: -120.2),
          (lat: 40.7, lng: -120.95),
          (lat: 43.252, lng: -126.453),
        ];
        expect(
          const RideOutline(points).encode(),
          r'_p~iF~ps|U_ulLnnqC_mqNvxq`@',
        );
      },
    );

    test(
      'an empty outline encodes to an empty string and decodes to empty',
      () {
        expect(const RideOutline([]).encode(), '');
        expect(RideOutline.decode('').points, isEmpty);
      },
    );
  });

  group('RideOutline.bounds', () {
    test(
      'bounds is the box around all points as south, west, north and east',
      () {
        const outline = RideOutline([
          (lat: 48.1, lng: 11.6),
          (lat: 48.3, lng: 11.4),
          (lat: 48.2, lng: 11.9),
        ]);
        expect(outline.bounds, (
          south: 48.1,
          west: 11.4,
          north: 48.3,
          east: 11.9,
        ));
      },
    );

    test('an empty outline has no bounds', () {
      expect(const RideOutline([]).bounds, isNull);
    });
  });
}
