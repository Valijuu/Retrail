import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/map/preview_projection.dart';
import 'package:retrail/map/route_sketch.dart';

void main() {
  group('sketchOffsets', () {
    test('empty input → empty', () {
      expect(sketchOffsets(const [], 100, 50), isEmpty);
    });

    test('all offsets land inside the box', () {
      const points = <RoutePoint>[
        (lat: 49.44, lng: 11.08),
        (lat: 49.45, lng: 11.10),
        (lat: 49.46, lng: 11.12),
      ];
      for (final o in sketchOffsets(points, 200, 100)) {
        expect(o.x, inInclusiveRange(0, 200));
        expect(o.y, inInclusiveRange(0, 100));
      }
    });

    test('inset keeps every offset at least that far from each edge', () {
      const points = <RoutePoint>[
        (lat: 49.40, lng: 11.00),
        (lat: 49.50, lng: 11.20),
        (lat: 49.45, lng: 11.10),
      ];
      for (final o in sketchOffsets(points, 200, 100, inset: 12)) {
        expect(o.x, inClosedOpenRange(12, 188.0001));
        expect(o.y, inClosedOpenRange(12, 88.0001));
      }
      // …and the route still spans the inset box on its limiting axis.
      final ys = sketchOffsets(points, 200, 100, inset: 12).map((o) => o.y);
      expect(ys.reduce((a, b) => a < b ? a : b), closeTo(12, 1e-6));
      expect(ys.reduce((a, b) => a > b ? a : b), closeTo(88, 1e-6));
    });

    test('eastern point is right of western; northern is above southern', () {
      const points = <RoutePoint>[
        (lat: 49.44, lng: 11.08), // SW
        (lat: 49.46, lng: 11.12), // NE
      ];
      final offsets = sketchOffsets(points, 200, 100);
      expect(offsets.last.x, greaterThan(offsets.first.x)); // east → larger x
      expect(offsets.last.y, lessThan(offsets.first.y)); // north → smaller y
    });

    test('a single point sits in the centre, not at the top edge (issue #31)',
        () {
      final o = sketchOffsets(const [(lat: 49.44, lng: 11.08)], 320, 112);
      expect(o.single.x, closeTo(160, 1e-9));
      expect(o.single.y, closeTo(56, 1e-9));
    });

    test('a due north-south line is centred horizontally', () {
      const points = <RoutePoint>[
        (lat: 49.44, lng: 11.08),
        (lat: 49.46, lng: 11.08),
      ];
      for (final o in sketchOffsets(points, 320, 112)) {
        expect(o.x, closeTo(160, 1e-9));
      }
    });
  });
}
