import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _style(String name) =>
    jsonDecode(File('assets/map/$name.json').readAsStringSync())
        as Map<String, dynamic>;

Map<String, dynamic> _layer(Map<String, dynamic> style, String id) =>
    (style['layers'] as List).cast<Map<String, dynamic>>()
        .firstWhere((l) => l['id'] == id);

void main() {
  test('both bundled styles read OpenMapTiles from OpenFreeMap', () {
    for (final name in ['retrail_light', 'retrail_dark']) {
      final sources = _style(name)['sources'] as Map<String, dynamic>;
      expect((sources['openmaptiles'] as Map)['url'],
          'https://tiles.openfreemap.org/planet', reason: name);
    }
  });

  test('Retrail Light is Liberty toned down: a muted grey-green ground, '
      'darker buildings, stronger green and water', () {
    final light = _style('retrail_light');
    expect(_layer(light, 'background')['paint']['background-color'], '#D2DDD2');
    expect(_layer(light, 'building')['paint']['fill-color'], '#BBC0B7');
    expect(_layer(light, 'park')['paint']['fill-color'], '#B7D2A2');
    expect(_layer(light, 'water')['paint']['fill-color'], '#82A9E2');
  });

  test('Retrail Dark sits on the app\'s dark terrain colour', () {
    final dark = _style('retrail_dark');
    expect(_layer(dark, 'background')['paint']['background-color'], '#20292A');
    expect(_layer(dark, 'water')['paint']['fill-color'], '#1B3346');
    expect(_layer(dark, 'building')['paint']['fill-color'], '#2C3A3A');
  });

  test('Retrail Dark greens open grass like parks (Dark has no grass layer)',
      () {
    final dark = _style('retrail_dark');
    final grass = _layer(dark, 'landcover_grass');
    expect(grass['source-layer'], 'landcover');
    expect(grass['paint']['fill-color'],
        _layer(dark, 'landuse_park')['paint']['fill-color']);
    final ids = [for (final l in dark['layers'] as List) l['id']];
    expect(ids.indexOf('landcover_grass'), lessThan(ids.indexOf('water')),
        reason: 'grass is drawn under water and roads');
  });

  test('Retrail Dark labels are readable on the lighter background', () {
    final dark = _style('retrail_dark');
    for (final l in (dark['layers'] as List).cast<Map<String, dynamic>>()) {
      if (l['type'] != 'symbol') continue;
      final paint = (l['paint'] ?? {}) as Map;
      if (!paint.containsKey('text-color')) continue;
      expect(paint['text-color'], isIn(['#A7B3B0', '#8FA9BD']), reason: l['id']);
    }
  });

  test('each bundled style names its origin and licence', () {
    for (final name in ['retrail_light', 'retrail_dark']) {
      final meta = _style(name)['metadata'] as Map<String, dynamic>;
      expect(meta['retrail:origin'], startsWith('https://tiles.openfreemap.org/styles/'));
      expect(meta['retrail:licence'], contains('CC BY 4.0'));
    }
  });
}
