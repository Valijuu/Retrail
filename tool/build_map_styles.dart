// Regenerates the bundled map styles from OpenFreeMap (Spec 19 §A).
// Run from the repo root: `dart run tool/build_map_styles.dart`.
import 'dart:convert';
import 'dart:io';

const _base = 'https://tiles.openfreemap.org/styles';
const _licence =
    'MIT (OpenFreeMap styles); design CC BY 4.0 OpenMapTiles — credited as "© OpenMapTiles"';

/// Retrail Light: OpenFreeMap Liberty in MapTiler topo-v2's colours, the map
/// Retrail used before Spec 19 (decision 2026-10-06 after device rounds with
/// warmer and greener variants): neutral grey ground, faint residential,
/// outlined buildings, olive green, teal water, dark grey footpaths and
/// near-black street names. Liberty's major-road yellow/orange already match.
const _lightPaint = <String, Map<String, Object>>{
  'background': {'background-color': '#EDEDED'},
  'landuse_residential': {
    'fill-color': '#BFBAAB',
    'fill-opacity': ['interpolate', ['linear'], ['zoom'], 4, 0.6, 16, 0.1],
  },
  'building': {'fill-color': '#CBC6BE', 'fill-outline-color': '#BFBAB0'},
  'landcover_wood': {'fill-color': '#BFCA9B'},
  'landcover_grass': {'fill-color': '#D5E0BE'},
  'park': {'fill-color': '#D5E0BE'},
  'water': {'fill-color': '#68A7C4'},
  'waterway_tunnel': {'line-color': '#68A7C4'},
  'waterway_river': {'line-color': '#68A7C4'},
  'waterway_other': {'line-color': '#68A7C4'},
  'road_minor_casing': {'line-color': '#CFCDC9'},
  'road_service_track_casing': {'line-color': '#CFCDC9'},
  'tunnel_street_casing': {'line-color': '#CFCDC9'},
  'tunnel_service_track_casing': {'line-color': '#CFCDC9'},
  'bridge_street_casing': {'line-color': '#CFCDC9'},
  'road_path_pedestrian': {'line-color': _lightPathColor},
  'tunnel_path_pedestrian': {'line-color': _lightPathColor},
  'bridge_path_pedestrian': {'line-color': _lightPathColor},
  // topo-v2's 3D buildings: half-transparent over the flat fill, so their
  // walls stay soft (Liberty's opaque ones cluttered the tracking view).
  'building-3d': {
    'fill-extrusion-color': '#ABA59C',
    'fill-extrusion-opacity': 0.5,
  },
  'highway-name-minor': _lightStreetName,
  'highway-name-major': _lightStreetName,
  'highway-name-path': _lightStreetName,
};
const _lightPathColor = [
  'interpolate', ['linear'], ['zoom'], 12, '#999999', 18, '#828282', //
];
const _lightStreetName = <String, Object>{
  'text-color': '#1F1F1F',
  'text-halo-color': '#FFFFFF',
  'text-halo-width': 1,
};


/// Retrail Dark: OpenFreeMap Dark in MapTiler basic-v2-dark's colours, the dark
/// map Retrail used before Spec 19: neutral dark grey ground, buildings a
/// shade darker, very dark green (basic-v2-dark's translucent green, blended
/// onto the ground), dark teal water, every road and path in one grey.
const _darkGround = '#2B2B2B';
const _darkGreen = '#252A1D';
const _darkRoad = '#454545';
const _darkRail = '#29292F';
const _darkPaint = <String, Map<String, Object>>{
  'background': {'background-color': _darkGround},
  'water': {'fill-color': '#223949'},
  'waterway': {'line-color': '#223949'},
  'landcover_ice_shelf': {'fill-color': _darkGround},
  'landcover_glacier': {'fill-color': _darkGround},
  'landuse_residential': {'fill-color': _darkGround},
  'landcover_wood': {'fill-color': _darkGreen},
  'landuse_park': {'fill-color': _darkGreen},
  'building': {'fill-color': '#252525', 'fill-outline-color': '#252525'},
  'aeroway-taxiway': {'line-color': _darkRoad},
  'aeroway-runway-casing': {'line-color': _darkRoad},
  'aeroway-area': {'fill-color': '#2E2E2E'},
  'aeroway-runway': {'line-color': _darkRoad},
  'road_area_pier': {'fill-color': '#2E2E2E'},
  'road_pier': {'line-color': '#2E2E2E'},
  'highway_path': {'line-color': _darkRoad},
  'highway_minor': {'line-color': _darkRoad},
  'highway_major_casing': {'line-color': _darkRoad},
  'highway_major_inner': {'line-color': _darkRoad},
  'highway_major_subtle': {'line-color': _darkRoad},
  'highway_motorway_casing': {'line-color': _darkRoad},
  'highway_motorway_inner': {'line-color': _darkRoad},
  'highway_motorway_subtle': {'line-color': _darkRoad},
  'railway_transit': {'line-color': _darkRail},
  'railway_transit_dashline': {'line-color': _darkGround},
  'railway_minor': {'line-color': _darkRail},
  'railway_minor_dashline': {'line-color': _darkGround},
  'railway': {'line-color': _darkRail},
  'railway_dashline': {'line-color': _darkGround},
  'highway_name_other': _darkStreetName,
  'highway_name_motorway': _darkStreetName,
  'water_name': {
    'text-color': '#8DA2B3',
    'text-halo-color': 'rgba(0,0,0,0.75)',
  },
};
const _darkStreetName = <String, Object>{
  'text-color': '#C2C2C2',
  'text-halo-color': '#000000',
  'text-halo-width': 1,
};

/// Every other dark label (places): basic-v2-dark's place labels.
const _darkPlaceLabel = <String, Object>{
  'text-color': '#DBDBDB',
  'text-halo-color': 'rgba(0,0,0,0.75)',
  'text-halo-width': 2,
};

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

/// Applies [paint] to [layers] by id and fails loudly when an id no longer
/// exists upstream (a renamed layer would otherwise drop a colour silently).
void _recolour(
    List<Map<String, dynamic>> layers, Map<String, Map<String, Object>> paint) {
  final ids = {for (final l in layers) l['id']};
  final missing = paint.keys.where((id) => !ids.contains(id));
  if (missing.isNotEmpty) throw StateError('layers gone upstream: $missing');
  for (final l in layers) {
    final p = (l['paint'] ??= <String, dynamic>{}) as Map<String, dynamic>;
    p.addAll(paint[l['id']] ?? const {});
  }
}

Future<void> main() async {
  final light = await _fetch('liberty');
  final lightLayers = (light['layers'] as List).cast<Map<String, dynamic>>();
  _recolour(lightLayers, _lightPaint);
  // Liberty stops its flat buildings at z14 where its opaque 3D ones took
  // over; under the half-transparent 3D layer they must go on, as in topo-v2.
  lightLayers.firstWhere((l) => l['id'] == 'building').remove('maxzoom');
  _write('retrail_light', light, 'liberty');

  final dark = await _fetch('dark');
  final darkLayers = (dark['layers'] as List).cast<Map<String, dynamic>>();
  for (final l in darkLayers) {
    final p = l['paint'] as Map<String, dynamic>?;
    if (l['type'] == 'symbol' && p != null && p.containsKey('text-color')) {
      p.addAll(_darkPlaceLabel);
    }
  }
  _recolour(darkLayers, _darkPaint);
  final water = darkLayers.indexWhere((l) => l['id'] == 'water');
  if (water < 0) throw StateError('dark: no water layer to put grass under');
  darkLayers.insert(water, {
    'id': 'landcover_grass',
    'type': 'fill',
    'source': 'openmaptiles',
    'source-layer': 'landcover',
    'filter': ['==', ['get', 'class'], 'grass'],
    'paint': {'fill-color': _darkGreen},
  });
  _write('retrail_dark', dark, 'dark');
}
