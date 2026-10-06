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

  test('Retrail Light takes MapTiler topo-v2\'s colours: neutral grey ground, '
      'faint residential, outlined buildings, olive green, teal water', () {
    final light = _style('retrail_light');
    expect(_layer(light, 'background')['paint']['background-color'], '#EDEDED');
    final residential = _layer(light, 'landuse_residential')['paint'] as Map;
    expect(residential['fill-color'], '#BFBAAB');
    expect(residential['fill-opacity'],
        ['interpolate', ['linear'], ['zoom'], 4, 0.6, 16, 0.1]);
    expect(_layer(light, 'building')['paint']['fill-color'], '#CBC6BE');
    expect(_layer(light, 'building')['paint']['fill-outline-color'], '#BFBAB0');
    expect(_layer(light, 'landcover_wood')['paint']['fill-color'], '#BFCA9B');
    expect(_layer(light, 'landcover_grass')['paint']['fill-color'], '#D5E0BE');
    expect(_layer(light, 'park')['paint']['fill-color'], '#D5E0BE');
    expect(_layer(light, 'water')['paint']['fill-color'], '#68A7C4');
    expect(_layer(light, 'road_minor_casing')['paint']['line-color'], '#CFCDC9');
  });

  test('Retrail Light draws footpaths as MapTiler did: dark grey lines, not '
      'white', () {
    expect(_layer(_style('retrail_light'), 'road_path_pedestrian')['paint']
        ['line-color'], ['interpolate', ['linear'], ['zoom'], 12, '#999999', 18, '#828282']);
  });

  test('Retrail Light has topo-v2\'s subtle 3D buildings: half-transparent '
      'extrusion from z14 over the flat fill', () {
    final light = _style('retrail_light');
    final ids = [for (final l in light['layers'] as List) l['id']];
    final extrusion = _layer(light, 'building-3d');
    expect(extrusion['type'], 'fill-extrusion');
    expect(extrusion['minzoom'], 14);
    final paint = extrusion['paint'] as Map;
    expect(paint['fill-extrusion-color'], '#ABA59C');
    expect(paint['fill-extrusion-opacity'], 0.5);
    expect(ids.indexOf('building'), lessThan(ids.indexOf('building-3d')));
  });

  test('Retrail Light keeps its flat buildings at tracking zoom too: Liberty '
      'stops them at z14, where its opaque 3D buildings took over', () {
    final building = _layer(_style('retrail_light'), 'building');
    expect(building.containsKey('maxzoom'), isFalse);
  });

  test('Retrail Light street names are near-black on a white halo (topo-v2)',
      () {
    final light = _style('retrail_light');
    for (final id in ['highway-name-minor', 'highway-name-major']) {
      final paint = _layer(light, id)['paint'] as Map;
      expect(paint['text-color'], '#1F1F1F', reason: id);
      expect(paint['text-halo-color'], '#FFFFFF', reason: id);
      expect(paint['text-halo-width'], 1, reason: id);
    }
  });

  test('Retrail Dark takes MapTiler basic-v2-dark\'s colours: neutral dark '
      'grey ground, buildings a shade darker, dark green, dark teal water', () {
    final dark = _style('retrail_dark');
    expect(_layer(dark, 'background')['paint']['background-color'], '#2B2B2B');
    expect(_layer(dark, 'landuse_residential')['paint']['fill-color'], '#2B2B2B');
    expect(_layer(dark, 'building')['paint']['fill-color'], '#252525');
    expect(_layer(dark, 'landcover_wood')['paint']['fill-color'], '#252A1D');
    expect(_layer(dark, 'landuse_park')['paint']['fill-color'], '#252A1D');
    expect(_layer(dark, 'water')['paint']['fill-color'], '#223949');
  });

  test('Retrail Dark draws every road and path in one grey, as basic-v2-dark',
      () {
    final dark = _style('retrail_dark');
    for (final id in [
      'highway_path', 'highway_minor', 'highway_major_casing',
      'highway_major_inner', 'highway_motorway_casing', 'highway_motorway_inner',
    ]) {
      expect(_layer(dark, id)['paint']['line-color'], '#454545', reason: id);
    }
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

  test('Retrail Dark labels: street names #C2C2C2 on a soft dark halo (a hard '
      'black 1 px halo looked jagged on the device), places #DBDBDB', () {
    final dark = _style('retrail_dark');
    for (final id in ['highway_name_other', 'highway_name_motorway']) {
      final paint = _layer(dark, id)['paint'] as Map;
      expect(paint['text-color'], '#C2C2C2', reason: id);
      expect(paint['text-halo-color'], '#1F1F1F', reason: id);
      expect(paint['text-halo-width'], 1.5, reason: id);
      expect(paint['text-halo-blur'], 0.5, reason: id);
    }
    final place = _layer(dark, 'place_town')['paint'] as Map;
    expect(place['text-color'], '#DBDBDB');
    expect(place['text-halo-color'], 'rgba(0,0,0,0.75)');
    expect(place['text-halo-width'], 2);
  });

  test('each bundled style names its origin and licence', () {
    for (final name in ['retrail_light', 'retrail_dark']) {
      final meta = _style(name)['metadata'] as Map<String, dynamic>;
      expect(meta['retrail:origin'], startsWith('https://tiles.openfreemap.org/styles/'));
      expect(meta['retrail:licence'], contains('CC BY 4.0'));
    }
  });
}
