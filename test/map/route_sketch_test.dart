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
