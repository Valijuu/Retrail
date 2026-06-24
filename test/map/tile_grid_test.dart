import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/map/preview_projection.dart';
import 'package:retrail/map/tile_grid.dart';

void main() {
  test('covers the slot with correctly-offset tiles', () {
    const points = <RoutePoint>[
      (lat: 49.4400, lng: 11.0800),
      (lat: 49.4450, lng: 11.1050),
    ];
    final framing = computeFraming(points, 411, 125);
    final tiles = tilesFor(framing);

    expect(tiles, isNotEmpty);
    expect(tiles.every((t) => t.z == framing.zoom.toInt()), isTrue);
    // The first column/row tile sits at or just above-left of the origin.
    for (final t in tiles) {
      expect(t.offsetXDp, greaterThan(-tileSize));
      expect(t.offsetXDp, lessThan(framing.widthDp.toDouble()));
      expect(t.offsetYDp, greaterThan(-tileSize));
      expect(t.offsetYDp, lessThan(framing.heightDp.toDouble()));
    }
  });

  test('wraps longitude tiles at the antimeridian', () {
    const framing = StaticFraming(
      centerLat: 0,
      centerLon: 179.9,
      zoom: 1,
      widthDp: 600,
      heightDp: 200,
    );
    final tiles = tilesFor(framing);
    expect(tiles, isNotEmpty);
    // 2^1 = 2 tiles per axis → x always in [0, 2).
    expect(tiles.every((t) => t.x >= 0 && t.x < 2), isTrue);
  });

  test('skips latitude tiles beyond the poles', () {
    const framing = StaticFraming(
      centerLat: 85,
      centerLon: 0,
      zoom: 1,
      widthDp: 200,
      heightDp: 600,
    );
    final tiles = tilesFor(framing);
    expect(tiles, isNotEmpty);
    expect(tiles.every((t) => t.y >= 0 && t.y < 2), isTrue);
  });
}
