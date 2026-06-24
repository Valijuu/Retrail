import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/map/preview_projection.dart';

void main() {
  // History card slot: full width (~411 dp on the test device) × 125 dp.
  const widthDp = 411;
  const heightDp = 125;

  group('computeFraming zoom', () {
    test('tiny-span ride caps zoom at max', () {
      const points = <RoutePoint>[
        (lat: 49.403000, lng: 11.178900),
        (lat: 49.403098, lng: 11.179016),
      ];
      expect(computeFraming(points, widthDp, heightDp).zoom, maxPreviewZoom);
    });

    test('single point uses max preview zoom', () {
      const points = <RoutePoint>[(lat: 49.403056, lng: 11.178963)];
      expect(computeFraming(points, widthDp, heightDp).zoom, maxPreviewZoom);
    });

    test('normal ride fits below max zoom', () {
      const points = <RoutePoint>[
        (lat: 49.440000, lng: 11.080000),
        (lat: 49.445000, lng: 11.105000),
      ];
      final z = computeFraming(points, widthDp, heightDp).zoom;
      expect(z, lessThan(maxPreviewZoom));
      expect(z, greaterThanOrEqualTo(1.0));
    });
  });

  group('projection', () {
    test('bounding-box center projects to slot center', () {
      const points = <RoutePoint>[
        (lat: 49.4400, lng: 11.0800),
        (lat: 49.4450, lng: 11.1050),
      ];
      final framing = computeFraming(points, widthDp, heightDp);
      final center =
          (lat: (49.4400 + 49.4450) / 2.0, lng: (11.0800 + 11.1050) / 2.0);
      final o = projectPoint(center, framing);
      expect(o.x, closeTo(widthDp / 2, 0.5));
      expect(o.y, closeTo(heightDp / 2, 0.5));
    });

    test('eastern point projects right of western', () {
      const points = <RoutePoint>[
        (lat: 49.4400, lng: 11.0800),
        (lat: 49.4400, lng: 11.1200),
      ];
      final f = computeFraming(points, widthDp, heightDp);
      final west = projectPoint((lat: 49.4400, lng: 11.0800), f);
      final east = projectPoint((lat: 49.4400, lng: 11.1200), f);
      expect(east.x, greaterThan(west.x));
    });

    test('northern point projects above southern (smaller y)', () {
      const points = <RoutePoint>[
        (lat: 49.4400, lng: 11.0800),
        (lat: 49.4600, lng: 11.0800),
      ];
      final f = computeFraming(points, widthDp, heightDp);
      final north = projectPoint((lat: 49.4600, lng: 11.0800), f);
      final south = projectPoint((lat: 49.4400, lng: 11.0800), f);
      expect(north.y, lessThan(south.y));
    });

    test('all points of a normal route project inside the slot', () {
      const points = <RoutePoint>[
        (lat: 49.4400, lng: 11.0800),
        (lat: 49.4425, lng: 11.0925),
        (lat: 49.4450, lng: 11.1050),
      ];
      final f = computeFraming(points, widthDp, heightDp);
      for (final p in points) {
        final o = projectPoint(p, f);
        expect(o.x, inInclusiveRange(0, widthDp.toDouble()));
        expect(o.y, inInclusiveRange(0, heightDp.toDouble()));
      }
    });
  });

  test('web mercator matches known anchors', () {
    expect(lonXAtZoom(-180.0, 0.0), closeTo(0.0, 1e-9));
    expect(lonXAtZoom(0.0, 0.0), closeTo(128.0, 1e-9));
    expect(lonXAtZoom(180.0, 0.0), closeTo(256.0, 1e-9));
    expect(latYAtZoom(0.0, 0.0), closeTo(128.0, 1e-9));
    expect(latYAtZoom(45.0, 0.0), lessThan(128.0));
  });
}
