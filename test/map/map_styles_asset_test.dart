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

  test('Retrail Light is Liberty dimmed and warm (matches the app\'s cream '
      'and its orange position marker), Liberty\'s own green and water', () {
    final light = _style('retrail_light');
    expect(_layer(light, 'background')['paint']['background-color'], '#EEE5DA');
    expect(_layer(light, 'landuse_residential')['paint']['fill-color'], '#E6DBCE');
    expect(_layer(light, 'building')['paint']['fill-color'], '#D7CABC');
    expect(_layer(light, 'park')['paint']['fill-color'], '#d8e8c8',
        reason: 'no green tint added: Liberty\'s park colour stays');
    expect(_layer(light, 'water')['paint']['fill-color'], 'rgb(158,189,255)');
  });

  test('Retrail Light draws buildings flat: no 3D extrusion (its dark walls '
      'cluttered the tracking view)', () {
    final types = [
      for (final l in _style('retrail_light')['layers'] as List) l['type'],
    ];
    expect(types, isNot(contains('fill-extrusion')));
  });

  test('Retrail Light draws its flat buildings at tracking zoom too: Liberty '
      'stops them at z14, where its 3D buildings took over', () {
    final building = _layer(_style('retrail_light'), 'building');
    expect(building.containsKey('maxzoom'), isFalse);
  });

  test('Retrail Light street names are darker with a ground-coloured halo', () {
    final light = _style('retrail_light');
    for (final id in ['highway-name-minor', 'highway-name-major']) {
      final paint = _layer(light, id)['paint'] as Map;
      expect(paint['text-color'], '#5A4E44', reason: id);
      expect(paint['text-halo-color'], '#EEE5DA', reason: id);
      expect(paint['text-halo-width'], 1.5, reason: id);
    }
  });

  test('Retrail Dark street names are lighter with a ground-coloured halo, '
      'roads a step brighter', () {
    final dark = _style('retrail_dark');
    for (final id in ['highway_name_other', 'highway_name_motorway']) {
      final paint = _layer(dark, id)['paint'] as Map;
      expect(paint['text-color'], '#BAC4C1', reason: id);
      expect(paint['text-halo-color'], '#181E1F', reason: id);
      expect(paint['text-halo-width'], 1.5, reason: id);
    }
    expect(_layer(dark, 'highway_minor')['paint']['line-color'], '#3B4746');
    expect(_layer(dark, 'highway_major_casing')['paint']['line-color'], '#4E5956');
  });

  test('Retrail Dark is a dark grey-green, a step darker than the app\'s '
      'dark terrain', () {
    final dark = _style('retrail_dark');
    expect(_layer(dark, 'background')['paint']['background-color'], '#181E1F');
    expect(_layer(dark, 'water')['paint']['fill-color'], '#15283A');
    expect(_layer(dark, 'building')['paint']['fill-color'], '#222B2B');
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
      expect(paint['text-color'], isIn(['#96A29F', '#7E98AC', '#BAC4C1']),
          reason: l['id']);
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
