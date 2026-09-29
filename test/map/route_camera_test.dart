import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/map/preview_projection.dart';
import 'package:retrail/map/route_camera.dart';

void main() {
  group('fitRouteCamera', () {
    test('an empty route has no camera → null', () {
      expect(fitRouteCamera(const [], width: 400, height: 400), isNull);
    });
    test('a single point centres on it at maxPreviewZoom (z16)', () {
      final camera = fitRouteCamera(
        const [(lat: 49.4, lng: 11.0)],
        width: 400,
        height: 400,
      );
      expect(camera, (lat: 49.4, lng: 11.0, zoom: maxPreviewZoom));
    });
    test('a standstill route (identical points) centres on it at '
        'maxPreviewZoom (z16)', () {
      const p = (lat: 49.4, lng: 11.0);
      final camera = fitRouteCamera(const [p, p, p], width: 400, height: 400);
      expect(camera, (lat: 49.4, lng: 11.0, zoom: maxPreviewZoom));
    });
    test('centres on the bounding-box midpoint → (49.45, 11.05)', () {
      final camera = fitRouteCamera(
        const [
          (lat: 49.42, lng: 11.00),
          (lat: 49.50, lng: 11.03),
          (lat: 49.40, lng: 11.10),
        ],
        width: 400,
        height: 400,
      )!;
      expect(camera.lat, closeTo(49.45, 1e-9));
      expect(camera.lng, closeTo(11.05, 1e-9));
    });
    test('an east-west route fits its width: 0.1° lng in 400 px − 2×24 padding '
        '→ zoom ≈ 11.273 (512-px world tiles)', () {
      final camera = fitRouteCamera(
        const [(lat: 49.4, lng: 11.0), (lat: 49.4, lng: 11.1)],
        width: 400,
        height: 400,
      )!;
      expect(camera.zoom, closeTo(11.273, 1e-3));
    });
    test('a north-south route fits its height in Web-Mercator: 0.1° lat at '
        '49.4° N in 400 px − 2×24 padding → zoom ≈ 10.652', () {
      final camera = fitRouteCamera(
        const [(lat: 49.4, lng: 11.0), (lat: 49.5, lng: 11.0)],
        width: 400,
        height: 400,
      )!;
      expect(camera.zoom, closeTo(10.652, 1e-3));
    });
    test('the tighter axis wins: 0.1° × 0.1° in an 800 × 400 viewport is '
        'height-bound → zoom ≈ 10.652', () {
      final camera = fitRouteCamera(
        const [(lat: 49.4, lng: 11.0), (lat: 49.5, lng: 11.1)],
        width: 800,
        height: 400,
      )!;
      expect(camera.zoom, closeTo(10.652, 1e-3));
    });
    test('every route point lands inside the viewport minus the default 24-px '
        'padding at the returned camera', () {
      const points = <RoutePoint>[
        (lat: 49.40, lng: 11.05),
        (lat: 49.46, lng: 11.12),
        (lat: 49.42, lng: 11.02),
        (lat: 49.47, lng: 11.09),
      ];
      const width = 360.0, height = 640.0, padding = 24.0;
      final camera = fitRouteCamera(points, width: width, height: height)!;
      // MapLibre's world is 512 px wide at zoom 0 — twice the 256-px raster
      // tile math of lonXAtZoom/latYAtZoom, i.e. one zoom level up.
      final z = camera.zoom + 1;
      final cx = lonXAtZoom(camera.lng, z);
      final cy = latYAtZoom(camera.lat, z);
      for (final p in points) {
        final x = lonXAtZoom(p.lng, z) - cx + width / 2;
        final y = latYAtZoom(p.lat, z) - cy + height / 2;
        expect(
          x,
          inInclusiveRange(padding - 1e-6, width - padding + 1e-6),
          reason: '$p x',
        );
        expect(
          y,
          inInclusiveRange(padding - 1e-6, height - padding + 1e-6),
          reason: '$p y',
        );
      }
    });
    test('a very short route (~7 m) is capped at maxPreviewZoom (z16)', () {
      final camera = fitRouteCamera(
        const [(lat: 49.4, lng: 11.0), (lat: 49.4, lng: 11.0001)],
        width: 400,
        height: 400,
      )!;
      expect(camera.zoom, maxPreviewZoom);
    });
    test('a viewport no bigger than its padding still yields a finite zoom '
        '(fit target ≥ 1 px)', () {
      final camera = fitRouteCamera(
        const [(lat: 49.4, lng: 11.0), (lat: 49.5, lng: 11.1)],
        width: 40,
        height: 40,
      )!;
      expect(camera.zoom.isFinite, isTrue, reason: '${camera.zoom}');
    });
  });
}
