// Regenerates the bundled map styles from OpenFreeMap (Spec 19 §A).
// Run from the repo root: `dart run tool/build_map_styles.dart`.
import 'dart:convert';
import 'dart:io';

const _base = 'https://tiles.openfreemap.org/styles';
const _licence =
    'MIT (OpenFreeMap styles); design CC BY 4.0 OpenMapTiles — credited as "© OpenMapTiles"';

/// Retrail Dark: OpenFreeMap Dark lifted onto the app's DarkMapTerrain.
const _darkPaint = <String, Map<String, String>>{
  'background': {'background-color': '#20292A'},
  'water': {'fill-color': '#1B3346'},
  'waterway': {'line-color': '#1B3346'},
  'landcover_ice_shelf': {'fill-color': '#20292A'},
  'landcover_glacier': {'fill-color': '#20292A'},
  'landuse_residential': {'fill-color': '#232D2E'},
  'landcover_wood': {'fill-color': '#213A2B'},
  'landuse_park': {'fill-color': '#233D2D'},
  'building': {'fill-color': '#2C3A3A', 'fill-outline-color': '#334242'},
  'aeroway-taxiway': {'line-color': '#2F3B3B'},
  'aeroway-runway-casing': {'line-color': '#3A4747'},
  'aeroway-area': {'fill-color': '#263132'},
  'aeroway-runway': {'line-color': '#2F3B3B'},
  'road_area_pier': {'fill-color': '#20292A'},
  'road_pier': {'line-color': '#20292A'},
  'highway_path': {'line-color': '#3C4A49'},
  'highway_minor': {'line-color': '#424F4E'},
  'highway_major_casing': {'line-color': '#56625F'},
  'highway_major_inner': {'line-color': '#4A5654'},
  'highway_major_subtle': {'line-color': '#4A5654'},
  'highway_motorway_casing': {'line-color': '#66716D'},
  'highway_motorway_inner': {'line-color': '#58635F'},
  'highway_motorway_subtle': {'line-color': '#4A5654'},
  'railway_transit': {'line-color': '#3A4545'},
  'railway_transit_dashline': {'line-color': '#20292A'},
  'railway_minor': {'line-color': '#3A4545'},
  'railway_minor_dashline': {'line-color': '#20292A'},
  'railway': {'line-color': '#3A4545'},
  'railway_dashline': {'line-color': '#20292A'},
};
const _labelColor = '#A7B3B0';
const _waterLabelColor = '#8FA9BD';
const _labelHalo = 'rgba(32,41,42,0.85)';

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
  _write('liberty', await _fetch('liberty'), 'liberty');

  final dark = await _fetch('dark');
  final layers = (dark['layers'] as List).cast<Map<String, dynamic>>();
  for (final l in layers) {
    final paint = (l['paint'] ??= <String, dynamic>{}) as Map<String, dynamic>;
    paint.addAll(_darkPaint[l['id']] ?? const {});
    if (l['type'] == 'symbol' && paint.containsKey('text-color')) {
      paint['text-color'] = l['id'] == 'water_name' ? _waterLabelColor : _labelColor;
      paint['text-halo-color'] = _labelHalo;
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
