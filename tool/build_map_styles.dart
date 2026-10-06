// Regenerates the bundled map styles from OpenFreeMap (Spec 19 §A).
// Run from the repo root: `dart run tool/build_map_styles.dart`.
import 'dart:convert';
import 'dart:io';

const _base = 'https://tiles.openfreemap.org/styles';
const _licence =
    'MIT (OpenFreeMap styles); design CC BY 4.0 OpenMapTiles — credited as "© OpenMapTiles"';

/// Retrail Light: OpenFreeMap Liberty dimmed and warmed — its near-white
/// ground glared, and a cool grey ground clashed with the app's warm cream and
/// its orange position marker. Only the ground, residential areas, buildings
/// and minor-road casings change; green, water and roads stay Liberty's.
const _lightPaint = <String, Map<String, String>>{
  'background': {'background-color': '#EEE5DA'},
  'landuse_residential': {'fill-color': '#E6DBCE'},
  'building': {'fill-color': '#D7CABC'},
  'aeroway_fill': {'fill-color': '#E4DACE'},
  'road_minor_casing': {'line-color': '#BDAE9E'},
  'road_service_track_casing': {'line-color': '#BDAE9E'},
  'tunnel_street_casing': {'line-color': '#BDAE9E'},
  'tunnel_service_track_casing': {'line-color': '#BDAE9E'},
  // Street names: darker, with a halo in the ground colour (Liberty's thin
  // #666 washed out on the warm ground).
  'highway-name-minor': {'text-color': '#5A4E44', 'text-halo-color': '#EEE5DA'},
  'highway-name-major': {'text-color': '#5A4E44', 'text-halo-color': '#EEE5DA'},
  'highway-name-path': {'text-halo-color': '#EEE5DA'},
};

/// Liberty's 3D buildings: their dark walls cluttered the tracking view
/// (Liberty's flat `building` fill stays).
const _lightDroppedLayers = {'building-3d'};
const _streetNameHaloWidth = 1.5;

/// Retrail Dark: OpenFreeMap Dark (near black) lifted onto a dark grey-green
/// a step below the app's DarkMapTerrain — the first version at that very
/// colour looked too light on the device.
const _darkPaint = <String, Map<String, String>>{
  'background': {'background-color': '#181E1F'},
  'water': {'fill-color': '#15283A'},
  'waterway': {'line-color': '#15283A'},
  'landcover_ice_shelf': {'fill-color': '#181E1F'},
  'landcover_glacier': {'fill-color': '#181E1F'},
  'landuse_residential': {'fill-color': '#1B2223'},
  'landcover_wood': {'fill-color': '#19291F'},
  'landuse_park': {'fill-color': '#1B2E22'},
  'building': {'fill-color': '#222B2B', 'fill-outline-color': '#283333'},
  'aeroway-taxiway': {'line-color': '#242E2E'},
  'aeroway-runway-casing': {'line-color': '#2E3939'},
  'aeroway-area': {'fill-color': '#1D2425'},
  'aeroway-runway': {'line-color': '#242E2E'},
  'road_area_pier': {'fill-color': '#181E1F'},
  'road_pier': {'line-color': '#181E1F'},
  'highway_path': {'line-color': '#2E3A39'},
  'highway_minor': {'line-color': '#3B4746'},
  'highway_major_casing': {'line-color': '#4E5956'},
  'highway_major_inner': {'line-color': '#424D4B'},
  'highway_major_subtle': {'line-color': '#424D4B'},
  'highway_motorway_casing': {'line-color': '#5E6865'},
  'highway_motorway_inner': {'line-color': '#515B58'},
  'highway_motorway_subtle': {'line-color': '#424D4B'},
  'railway_transit': {'line-color': '#2D3737'},
  'railway_transit_dashline': {'line-color': '#181E1F'},
  'railway_minor': {'line-color': '#2D3737'},
  'railway_minor_dashline': {'line-color': '#181E1F'},
  'railway': {'line-color': '#2D3737'},
  'railway_dashline': {'line-color': '#181E1F'},
};
const _labelColor = '#96A29F';
const _waterLabelColor = '#7E98AC';
const _labelHalo = 'rgba(24,30,31,0.85)';

/// Street names: lighter than the other labels, on a solid halo in the ground
/// colour (they washed out at #96A29F with a thin translucent halo).
const _darkStreetNameLayers = {'highway_name_other', 'highway_name_motorway'};
const _darkStreetNameColor = '#BAC4C1';
const _darkStreetNameHalo = '#181E1F';

Future<Map<String, dynamic>> _fetch(String name) async {
  final client = HttpClient()..userAgent = 'Retrail (io.github.valijuu.retrail)';
  final res = await (await client.getUrl(Uri.parse('$_base/$name'))).close();
  if (res.statusCode != 200) throw StateError('$name: HTTP ${res.statusCode}');
  final body = await res.transform(utf8.decoder).join();
  client.close();
  return jsonDecode(body) as Map<String, dynamic>;
}

void _write(String name, Map<String, dynamic> style, String origin) {
  style['metadata'] = {
    ...?(style['metadata'] as Map<String, dynamic>?),
    'retrail:origin': '$_base/$origin',
    'retrail:licence': _licence,
  };
  File('assets/map/$name.json')
    ..createSync(recursive: true)
    ..writeAsStringSync(const JsonEncoder.withIndent(' ').convert(style));
}

Future<void> main() async {
  final light = await _fetch('liberty');
  final lightLayers = (light['layers'] as List).cast<Map<String, dynamic>>()
    ..removeWhere((l) => _lightDroppedLayers.contains(l['id']));
  for (final l in lightLayers) {
    final paint = (l['paint'] ??= <String, dynamic>{}) as Map<String, dynamic>;
    paint.addAll(_lightPaint[l['id']] ?? const {});
    // Liberty stops its flat buildings at z14 where the 3D ones took over:
    // without the 3D layer they must go on at tracking zoom.
    if (l['id'] == 'building') l.remove('maxzoom');
    if (l['id'] == 'highway-name-minor' || l['id'] == 'highway-name-major') {
      paint['text-halo-width'] = _streetNameHaloWidth;
    }
  }
  _write('retrail_light', light, 'liberty');

  final dark = await _fetch('dark');
  final layers = (dark['layers'] as List).cast<Map<String, dynamic>>();
  for (final l in layers) {
    final paint = (l['paint'] ??= <String, dynamic>{}) as Map<String, dynamic>;
    paint.addAll(_darkPaint[l['id']] ?? const {});
    if (l['type'] == 'symbol' && paint.containsKey('text-color')) {
      paint['text-color'] = l['id'] == 'water_name' ? _waterLabelColor : _labelColor;
      paint['text-halo-color'] = _labelHalo;
    }
    if (_darkStreetNameLayers.contains(l['id'])) {
      paint['text-color'] = _darkStreetNameColor;
      paint['text-halo-color'] = _darkStreetNameHalo;
      paint['text-halo-width'] = _streetNameHaloWidth;
    }
  }
  final grass = {
    'id': 'landcover_grass',
    'type': 'fill',
    'source': 'openmaptiles',
    'source-layer': 'landcover',
    'filter': ['==', ['get', 'class'], 'grass'],
    'paint': {'fill-color': _darkPaint['landuse_park']!['fill-color']},
  };
  layers.insert(layers.indexWhere((l) => l['id'] == 'water'), grass);
  _write('retrail_dark', dark, 'dark');
}
