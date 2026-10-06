import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/map/openfreemap.dart';

void main() {
  group('parseTileJson', () {
    test('reads tiles[0] and maxzoom from OpenFreeMap\'s TileJSON — '
        'template …/planet/20260927_080001_pt/{z}/{x}/{y}.pbf, maxZoom 14', () {
      final t = parseTileJson(
        '{"tiles":["https://tiles.openfreemap.org/planet/'
        '20260927_080001_pt/{z}/{x}/{y}.pbf"],"maxzoom":14}',
      );
      expect(
        t.template,
        'https://tiles.openfreemap.org/planet/20260927_080001_pt/{z}/{x}/{y}.pbf',
      );
      expect(t.maxZoom, 14);
    });
    test('throws FormatException when tiles is missing or empty', () {
      expect(() => parseTileJson('{"maxzoom":14}'), throwsFormatException);
      expect(
        () => parseTileJson('{"tiles":[],"maxzoom":14}'),
        throwsFormatException,
      );
    });
    test('throws FormatException when maxzoom is missing', () {
      expect(
        () => parseTileJson('{"tiles":["a/{z}/{x}/{y}"]}'),
        throwsFormatException,
      );
    });
  });

  test('tileUrl fills {z}, {x}, {y} into the versioned template — '
      'https://t/p/v1/14/8675/5426.pbf', () {
    expect(
      tileUrl('https://t/p/v1/{z}/{x}/{y}.pbf', 14, 8675, 5426),
      Uri.parse('https://t/p/v1/14/8675/5426.pbf'),
    );
  });

  group('overzoomTile', () {
    test(
      'at or below maxZoom: the tile itself, scale 1, square (0, 0, 256)',
      () {
        final o = overzoomTile(14, 8675, 5426, maxZoom: 14);
        expect([o.z, o.x, o.y, o.scale], [14, 8675, 5426, 1]);
        expect([o.left, o.top, o.size], [0, 0, 256]);
      },
    );
    test('z16 over maxZoom 14: parent (x>>2, y>>2), scale 4, square 64 wide '
        'at (x%4*64, y%4*64)', () {
      final o = overzoomTile(16, 34703, 21707, maxZoom: 14);
      expect([o.z, o.x, o.y, o.scale], [14, 8675, 5426, 4]);
      expect([o.left, o.top, o.size], [3 * 64, 3 * 64, 64]);
    });
    test(
      'z15 over maxZoom 14: parent (x>>1, y>>1), scale 2, square 128 wide',
      () {
        final o = overzoomTile(15, 17350, 10853, maxZoom: 14);
        expect([o.z, o.x, o.y, o.scale], [14, 8675, 5426, 2]);
        expect([o.left, o.top, o.size], [0, 128, 128]);
      },
    );
  });

  group('previewStyle', () {
    final style = {
      'version': 8,
      'layers': [
        {'id': 'bg', 'type': 'background'},
        {'id': 'shade', 'type': 'raster'},
        {'id': 'road', 'type': 'line'},
        {'id': '3d', 'type': 'fill-extrusion'},
        {'id': 'names', 'type': 'symbol'},
      ],
    };
    List<Object?> ids(Map<String, dynamic> s) => [
      for (final l in s['layers'] as List) (l as Map)['id'],
    ];

    test('drops raster and fill-extrusion layers', () {
      final kept = ids(previewStyle(style));
      expect(kept, isNot(contains('shade')));
      expect(kept, isNot(contains('3d')));
    });
    test('keeps symbol and every other layer in order — bg, road, names', () {
      expect(ids(previewStyle(style)), ['bg', 'road', 'names']);
    });
    test('leaves the input style untouched — still 5 layers', () {
      previewStyle(style);
      expect(style['layers'] as List, hasLength(5));
    });
  });
}
