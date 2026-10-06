# OpenFreeMap (Spec 19) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace MapTiler with OpenFreeMap everywhere: live map (Liberty / bundled Retrail Dark), history previews drawn from vector tiles in Dart, a credit that collapses to ⓘ, no MapTiler key left.

**Architecture:** The preview pipeline keeps its seam `PreviewTileProvider` (`lib/map/preview_snapshot.dart`); a new `OpenFreeMapTileProvider` fetches OpenMapTiles vector tiles (TileJSON → versioned URL, z ≤ 14, overzoom above), parses them in an isolate and paints them with `vector_tile_renderer` into one 768 px image per 256 dp grid tile. Pure helpers (TileJSON, tile URL, overzoom, preview style filter) live in `lib/map/openfreemap.dart`. The live map takes a style URL (Liberty) or a JSON string (bundled Retrail Dark).

**Tech Stack:** Flutter, Riverpod (hand-written providers), `maplibre` 0.3.6, `vector_tile_renderer` 6.1.0, `http`, `flutter_test` + `http/testing.dart` `MockClient`.

**Spec:** `docs/specs/19-openfreemap.md` — read it first; this plan implements it section by section.

## Global Constraints

- Branch `phase/19-openfreemap` (already created off `main`). Commits: Conventional Commits in English, `type(scope): summary`, reference `(#58)`, end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Pure logic in `lib/map/openfreemap.dart` (no Flutter imports) → **EXACT via `Skill({ skill: "tdd-dart" })`**. Providers/widgets → Red-Green-Refactor (test first, see it fail, minimal code). Device checks accompany, not precede.
- No user-facing literal in widgets: ARB keys in both `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`, then `flutter gen-l10n`.
- No hardcoded hex in Dart widgets; colours in the bundled style JSON are map data, not UI tokens (documented in `lib/core/theme/CLAUDE.md`).
- A class ≤ 400 lines of code. No dead code: everything MapTiler is deleted once replaced.
- Never commit real ride data; test fixtures are public places only (OSM data, ODbL).
- Credit text: `© OpenMapTiles` → `https://openmaptiles.org/`, `© OpenStreetMap` → `https://www.openstreetmap.org/copyright`, identical in EN and DE.
- User-Agent for every OpenFreeMap request from Dart: `Retrail (io.github.valijuu.retrail)`.
- Done = `flutter analyze` clean and `flutter test` green.

## Review Focus

1. **Weekly data rotation:** the cached TileJSON template points at a retired `planet/<date>` → a tile answers 404 → the next tile must re-resolve TileJSON (test in Task 3).
2. **Four sub-tiles of one z14 parent requested at once** (a z16 preview fetches its grid via `Future.wait`) → exactly one HTTP request for the parent (test in Task 3).
3. **TileJSON fetch fails once** (offline at app start, then online) → that preview is incomplete, but a later preview must retry the TileJSON, not stay broken for the process (test in Task 3).
4. **The second live map after app start** (ride map, then detail dialog) → starts as ⓘ; a brightness rebuild of the same map must not re-expand it (test in Task 6).
5. **Tapping a credit link while expanded** → opens the link; the global pointer route must not collapse it before the tap lands (test in Task 6).

---

## File structure

| File | Responsibility |
|---|---|
| `tool/build_map_styles.dart` (new) | Downloads OpenFreeMap Liberty + Dark, writes `assets/map/liberty.json` (copy) and `assets/map/retrail_dark.json` (recoloured). Re-run when updating styles. |
| `assets/map/liberty.json`, `assets/map/retrail_dark.json` (new) | Bundled styles. |
| `lib/map/openfreemap.dart` (new) | Pure: URLs/asset paths/constants, `TileJson`, `parseTileJson`, `tileUrl`, `OverzoomTile`, `overzoomTile`, `previewStyle`. |
| `lib/map/openfreemap_tile_provider.dart` (new) | `OpenFreeMapTileProvider implements PreviewTileProvider`. |
| `lib/map/map_attribution.dart` | New credit texts, `collapsible` mode, `MapCreditSession` + `mapCreditSessionProvider`. |
| `lib/map/live_map.dart` | `liveMapStyle(...)` replaces `liveMapStyleUrl`; loads the dark style asset. |
| `lib/features/active_ride/active_ride_providers.dart` | Wires the new tile provider. |
| `lib/map/route_preview_cache.dart` | `_cacheVersion` 6 → 7. |
| Deleted | `lib/map/maptiler_tile_provider.dart`, `test/map/maptiler_tile_provider_test.dart`, `lib/map/map_style.dart`; MapTiler members of `lib/map/map_config.dart`. |

---

### Task 1: Bundled map styles (Liberty copy + Retrail Dark)

**Files:**
- Create: `tool/build_map_styles.dart`, `assets/map/liberty.json`, `assets/map/retrail_dark.json`, `test/map/map_styles_asset_test.dart`
- Modify: `pubspec.yaml` (assets), `lib/core/theme/CLAUDE.md` (map style colours)

**Interfaces:**
- Produces: asset paths `assets/map/liberty.json`, `assets/map/retrail_dark.json` (constants for them are added in Task 2 as `kLibertyStyleAsset` / `kRetrailDarkStyleAsset`).

- [ ] **Step 1: Write the failing asset test** — `test/map/map_styles_asset_test.dart`:

```dart
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
    for (final name in ['liberty', 'retrail_dark']) {
      final sources = _style(name)['sources'] as Map<String, dynamic>;
      expect((sources['openmaptiles'] as Map)['url'],
          'https://tiles.openfreemap.org/planet', reason: name);
    }
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
    for (final name in ['liberty', 'retrail_dark']) {
      final meta = _style(name)['metadata'] as Map<String, dynamic>;
      expect(meta['retrail:origin'], startsWith('https://tiles.openfreemap.org/styles/'));
      expect(meta['retrail:licence'], contains('CC BY 4.0'));
    }
  });
}
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/map/map_styles_asset_test.dart` → `PathNotFoundException` for `assets/map/liberty.json`.

- [ ] **Step 3: Write the generator** — `tool/build_map_styles.dart`:

```dart
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
```

- [ ] **Step 4: Generate and register the assets**

Run: `dart run tool/build_map_styles.dart`
In `pubspec.yaml` under `flutter: assets:` add the line `    - assets/map/` after `- assets/branding/app_icon_foreground.png`. Then `flutter pub get`.

- [ ] **Step 5: Run the test, expect PASS** — `flutter test test/map/map_styles_asset_test.dart`.

- [ ] **Step 6: Document** — in `lib/core/theme/CLAUDE.md` add a section after "Colors — dark":

```markdown
## Map styles (map data, not UI tokens)

The live map and the previews use OpenFreeMap styles (Spec 19), generated by `tool/build_map_styles.dart` into `assets/map/`:
- Light: **Liberty** (unchanged copy for previews; the live map loads it by URL).
- Dark: **Retrail Dark** = OpenFreeMap Dark recoloured onto `DarkMapTerrain` `#20292A`: water `#1B3346`, park/grass `#233D2D`, wood `#213A2B`, buildings `DarkMapTerrainGrid` `#2C3A3A`, roads `#3C4A49` (path) … `#66716D` (motorway casing), labels `#A7B3B0` (water `#8FA9BD`) on a `rgba(32,41,42,0.85)` halo. Change colours in the generator, not in the JSON.
```

- [ ] **Step 7: Commit**

```bash
git add tool/build_map_styles.dart assets/map pubspec.yaml test/map/map_styles_asset_test.dart lib/core/theme/CLAUDE.md
git commit -m "feat(map): bundled liberty and retrail dark styles from openfreemap (#58)"
```

---

### Task 2: Pure OpenFreeMap helpers (EXACT)

**Files:**
- Create: `lib/map/openfreemap.dart`, `test/map/openfreemap_test.dart`

**Interfaces:**
- Produces (exact):

```dart
const String kOpenFreeMapTileJsonUrl = 'https://tiles.openfreemap.org/planet';
const String kLibertyStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';
const String kLibertyStyleAsset = 'assets/map/liberty.json';
const String kRetrailDarkStyleAsset = 'assets/map/retrail_dark.json';
const String kOpenFreeMapSource = 'openmaptiles';
const String kMapUserAgent = 'Retrail (io.github.valijuu.retrail)';
const int kPreviewTileDp = 256;

class TileJson { const TileJson({required this.template, required this.maxZoom});
  final String template; final int maxZoom; }
TileJson parseTileJson(String body);            // throws FormatException on bad input
Uri tileUrl(String template, int z, int x, int y);
class OverzoomTile { const OverzoomTile({required this.z, required this.x, required this.y,
  required this.scale, required this.left, required this.top, required this.size});
  final int z, x, y;   // the tile actually fetched (≤ maxZoom)
  final int scale;     // 2^dz, 1 when no overzoom
  final double left, top, size; // the drawn square inside the fetched tile, in its 256-unit space
}
OverzoomTile overzoomTile(int z, int x, int y, {required int maxZoom});
Map<String, dynamic> previewStyle(Map<String, dynamic> style); // drops raster + fill-extrusion layers
```

- [ ] **Step 1: Run the EXACT workflow** — `Skill({ skill: "tdd-dart" })`, then `/test-list-dart` with this test list (all start skipped), then `/red-dart` + `/green-dart` per test, `refactor` subagent at the end:

```
parseTileJson
  - reads tiles[0] and maxzoom from OpenFreeMap's TileJSON
  - throws FormatException when tiles is missing or empty
  - throws FormatException when maxzoom is missing
tileUrl
  - fills {z}, {x}, {y} into the versioned template
overzoomTile
  - at or below maxZoom: the tile itself, scale 1, whole square (0, 0, 256)
  - z16 over maxZoom 14: parent (x>>2, y>>2), scale 4, square 64 wide at (x%4*64, y%4*64)
  - z15 over maxZoom 14: parent (x>>1, y>>1), scale 2, square 128 wide
previewStyle
  - drops raster and fill-extrusion layers
  - keeps symbol (labels) and every other layer in order
  - leaves the input style untouched
```

Expected test bodies (write them in `test/map/openfreemap_test.dart`, one active at a time per EXACT):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/map/openfreemap.dart';

void main() {
  group('parseTileJson', () {
    test('reads tiles[0] and maxzoom from OpenFreeMap\'s TileJSON', () {
      final t = parseTileJson(
          '{"tiles":["https://tiles.openfreemap.org/planet/20260927_080001_pt/{z}/{x}/{y}.pbf"],"maxzoom":14}');
      expect(t.template,
          'https://tiles.openfreemap.org/planet/20260927_080001_pt/{z}/{x}/{y}.pbf');
      expect(t.maxZoom, 14);
    });
    test('throws FormatException when tiles is missing or empty', () {
      expect(() => parseTileJson('{"maxzoom":14}'), throwsFormatException);
      expect(() => parseTileJson('{"tiles":[],"maxzoom":14}'), throwsFormatException);
    });
    test('throws FormatException when maxzoom is missing', () {
      expect(() => parseTileJson('{"tiles":["a/{z}/{x}/{y}"]}'), throwsFormatException);
    });
  });

  test('tileUrl fills {z}, {x}, {y} into the versioned template', () {
    expect(tileUrl('https://t/p/v1/{z}/{x}/{y}.pbf', 14, 8675, 5426),
        Uri.parse('https://t/p/v1/14/8675/5426.pbf'));
  });

  group('overzoomTile', () {
    test('at or below maxZoom: the tile itself, scale 1, whole square', () {
      final o = overzoomTile(14, 8675, 5426, maxZoom: 14);
      expect([o.z, o.x, o.y, o.scale], [14, 8675, 5426, 1]);
      expect([o.left, o.top, o.size], [0, 0, 256]);
    });
    test('z16 over maxZoom 14: parent, scale 4, square 64 wide', () {
      final o = overzoomTile(16, 34703, 21707, maxZoom: 14);
      expect([o.z, o.x, o.y, o.scale], [14, 8675, 5426, 4]);
      expect([o.left, o.top, o.size], [3 * 64, 3 * 64, 64]);
    });
    test('z15 over maxZoom 14: parent, scale 2, square 128 wide', () {
      final o = overzoomTile(15, 17350, 10853, maxZoom: 14);
      expect([o.z, o.x, o.y, o.scale], [14, 8675, 5426, 2]);
      expect([o.left, o.top, o.size], [0, 128, 128]);
    });
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
    test('drops raster and fill-extrusion layers', () {
      final ids = [for (final l in previewStyle(style)['layers'] as List) l['id']];
      expect(ids, isNot(contains('shade')));
      expect(ids, isNot(contains('3d')));
    });
    test('keeps symbol and every other layer in order', () {
      final ids = [for (final l in previewStyle(style)['layers'] as List) l['id']];
      expect(ids, ['bg', 'road', 'names']);
    });
    test('leaves the input style untouched', () {
      previewStyle(style);
      expect((style['layers'] as List).length, 5);
    });
  });
}
```

Reference implementation the green steps converge on (`lib/map/openfreemap.dart`, no Flutter imports):

```dart
import 'dart:convert';
import 'dart:math' as math;

/// OpenFreeMap (Spec 19): tile and style locations plus the pure helpers the
/// preview tile provider and the live map share.
const String kOpenFreeMapTileJsonUrl = 'https://tiles.openfreemap.org/planet';
const String kLibertyStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';
const String kLibertyStyleAsset = 'assets/map/liberty.json';
const String kRetrailDarkStyleAsset = 'assets/map/retrail_dark.json';

/// The vector source name in the OpenFreeMap styles.
const String kOpenFreeMapSource = 'openmaptiles';

/// Sent with every OpenFreeMap request: a free service, so the app says who it is.
const String kMapUserAgent = 'Retrail (io.github.valijuu.retrail)';

/// A preview grid tile's side in dp (`tile_grid.dart`'s `tileSize`).
const int kPreviewTileDp = 256;

/// Layer types a preview never draws: Natural Earth shading (z ≤ 6) and 3D
/// buildings.
const Set<String> _previewDroppedTypes = {'raster', 'fill-extrusion'};

class TileJson {
  const TileJson({required this.template, required this.maxZoom});

  /// Versioned tile URL template, e.g. `…/planet/20260927_080001_pt/{z}/{x}/{y}.pbf`.
  final String template;
  final int maxZoom;
}

TileJson parseTileJson(String body) {
  final json = jsonDecode(body);
  if (json is! Map<String, dynamic>) throw const FormatException('TileJSON: not an object');
  final tiles = json['tiles'];
  final maxZoom = json['maxzoom'];
  if (tiles is! List || tiles.isEmpty || tiles.first is! String) {
    throw const FormatException('TileJSON: no tiles');
  }
  if (maxZoom is! num) throw const FormatException('TileJSON: no maxzoom');
  return TileJson(template: tiles.first as String, maxZoom: maxZoom.toInt());
}

Uri tileUrl(String template, int z, int x, int y) => Uri.parse(template
    .replaceAll('{z}', '$z')
    .replaceAll('{x}', '$x')
    .replaceAll('{y}', '$y'));

class OverzoomTile {
  const OverzoomTile({required this.z, required this.x, required this.y,
      required this.scale, required this.left, required this.top, required this.size});
  final int z, x, y;
  final int scale;
  final double left, top, size;
}

/// The tile to fetch for grid tile `z/x/y` when the data stops at [maxZoom]:
/// above it, the ancestor at [maxZoom] and the square of it that `z/x/y`
/// covers, drawn [OverzoomTile.scale] times larger.
OverzoomTile overzoomTile(int z, int x, int y, {required int maxZoom}) {
  final dz = math.max(0, z - maxZoom);
  final scale = 1 << dz;
  final size = kPreviewTileDp / scale;
  return OverzoomTile(
    z: z - dz,
    x: x >> dz,
    y: y >> dz,
    scale: scale,
    left: (x % scale) * size,
    top: (y % scale) * size,
    size: size,
  );
}

/// [style] without the layers a preview never draws; labels stay.
Map<String, dynamic> previewStyle(Map<String, dynamic> style) => {
      ...style,
      'layers': [
        for (final l in style['layers'] as List)
          if (!_previewDroppedTypes.contains((l as Map)['type'])) l,
      ],
    };
```

- [ ] **Step 2: Verify** — `flutter test test/map/openfreemap_test.dart` → all pass, none skipped.

- [ ] **Step 3: Commit**

```bash
git add lib/map/openfreemap.dart test/map/openfreemap_test.dart
git commit -m "feat(map): openfreemap tilejson, tile url, overzoom and preview style helpers (#58)"
```

---

### Task 3: `OpenFreeMapTileProvider`

**Files:**
- Create: `lib/map/openfreemap_tile_provider.dart`, `test/map/openfreemap_tile_provider_test.dart`, `test/fixtures/map/14_8675_5426.pbf`
- Modify: `pubspec.yaml` (dependency)

**Interfaces:**
- Consumes: Task 2 (`parseTileJson`, `tileUrl`, `overzoomTile`, `previewStyle`, constants); `PreviewTileProvider` (`lib/map/preview_snapshot.dart`: `Future<ui.Image?> tile(int z, int x, int y, ui.Brightness brightness)`); `previewPixelRatio` (`lib/map/preview_projection.dart`).
- Produces:

```dart
class OpenFreeMapTileProvider implements PreviewTileProvider {
  OpenFreeMapTileProvider({
    http.Client? client,
    Future<String> Function(String asset)? loadAsset, // default rootBundle.loadString
    this.pixelRatio = previewPixelRatio,
    this.timeout = const Duration(seconds: 8),
    this.cacheSize = 24,
  });
}
```

- [ ] **Step 1: Add the dependency and the fixture**

```bash
flutter pub add vector_tile_renderer:6.1.0
mkdir -p test/fixtures/map
T=$(curl -s -A 'Retrail (io.github.valijuu.retrail)' https://tiles.openfreemap.org/planet | python3 -c "import json,sys;print(json.load(sys.stdin)['tiles'][0])")
curl -s -A 'Retrail (io.github.valijuu.retrail)' -o test/fixtures/map/14_8675_5426.pbf "$(echo $T | sed 's/{z}/14/;s/{x}/8675/;s/{y}/5426/')"
ls -la test/fixtures/map/14_8675_5426.pbf   # ~13 KB: the Brocken, Harz (public summit, no ride data)
```

- [ ] **Step 2: Write the failing tests** — `test/map/openfreemap_tile_provider_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:retrail/map/openfreemap.dart';
import 'package:retrail/map/openfreemap_tile_provider.dart';

const _tileJson =
    '{"tiles":["https://t.example/planet/v1/{z}/{x}/{y}.pbf"],"maxzoom":14}';
final _pbf = File('test/fixtures/map/14_8675_5426.pbf').readAsBytesSync();

/// Bundled styles from disk (the provider loads them through [loadAsset]).
Future<String> _asset(String path) async => File(path).readAsString();

class _Server {
  final requests = <http.Request>[];
  int tileJsonCalls = 0;
  int Function(Uri tile)? tileStatus;
  bool tileJsonFails = false;

  MockClient get client => MockClient((r) async {
        requests.add(r);
        if (r.url.toString() == kOpenFreeMapTileJsonUrl) {
          tileJsonCalls++;
          if (tileJsonFails) return http.Response('down', 503);
          return http.Response(_tileJson, 200);
        }
        final status = tileStatus?.call(r.url) ?? 200;
        return status == 200
            ? http.Response.bytes(_pbf, 200)
            : http.Response('', status);
      });

  List<Uri> get tileUrls => [
        for (final r in requests)
          if (r.url.toString() != kOpenFreeMapTileJsonUrl) r.url
      ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  OpenFreeMapTileProvider provider(_Server s) =>
      OpenFreeMapTileProvider(client: s.client, loadAsset: _asset);

  test('a z14 tile becomes a 768 px image (256 dp × pixel ratio 3)', () async {
    final s = _Server();
    final image = await provider(s).tile(14, 8675, 5426, ui.Brightness.light);
    expect(image, isNotNull);
    expect([image!.width, image.height], [768, 768]);
    image.dispose();
  });

  test('fetches the versioned URL from TileJSON with the Retrail user agent',
      () async {
    final s = _Server();
    (await provider(s).tile(14, 8675, 5426, ui.Brightness.dark))?.dispose();
    expect(s.tileUrls, [Uri.parse('https://t.example/planet/v1/14/8675/5426.pbf')]);
    expect(s.requests.every((r) => r.headers['User-Agent'] == kMapUserAgent), isTrue);
  });

  test('resolves TileJSON once for many tiles', () async {
    final s = _Server();
    final p = provider(s);
    (await p.tile(14, 8675, 5426, ui.Brightness.light))?.dispose();
    (await p.tile(14, 8676, 5426, ui.Brightness.light))?.dispose();
    expect(s.tileJsonCalls, 1);
  });

  test('a z16 grid tile draws from its z14 parent, fetched once for all four',
      () async {
    final s = _Server();
    final p = provider(s);
    final images = await Future.wait([
      for (final (x, y) in [(34700, 21704), (34701, 21704), (34700, 21705), (34701, 21705)])
        p.tile(16, x, y, ui.Brightness.light),
    ]);
    expect(images.every((i) => i != null && i.width == 768), isTrue);
    for (final i in images) {
      i!.dispose();
    }
    expect(s.tileUrls, [Uri.parse('https://t.example/planet/v1/14/8675/5426.pbf')]);
  });

  test('both themes share one fetched tile', () async {
    final s = _Server();
    final p = provider(s);
    (await p.tile(14, 8675, 5426, ui.Brightness.light))?.dispose();
    (await p.tile(14, 8675, 5426, ui.Brightness.dark))?.dispose();
    expect(s.tileUrls, hasLength(1));
  });

  test('a 404 (data version moved on) gives null and re-resolves TileJSON',
      () async {
    final s = _Server()..tileStatus = (_) => 404;
    final p = provider(s);
    expect(await p.tile(14, 8675, 5426, ui.Brightness.light), isNull);
    s.tileStatus = null;
    (await p.tile(14, 8676, 5426, ui.Brightness.light))?.dispose();
    expect(s.tileJsonCalls, 2);
  });

  test('a failed TileJSON gives null now and is retried later', () async {
    final s = _Server()..tileJsonFails = true;
    final p = provider(s);
    expect(await p.tile(14, 8675, 5426, ui.Brightness.light), isNull);
    s.tileJsonFails = false;
    final image = await p.tile(14, 8675, 5426, ui.Brightness.light);
    expect(image, isNotNull);
    image!.dispose();
    expect(s.tileJsonCalls, 2);
  });

  test('a failed tile is not cached: the next request fetches again', () async {
    var fail = true;
    final s = _Server()..tileStatus = (_) => fail ? 500 : 200;
    final p = provider(s);
    expect(await p.tile(14, 8675, 5426, ui.Brightness.light), isNull);
    fail = false;
    final image = await p.tile(14, 8675, 5426, ui.Brightness.light);
    expect(image, isNotNull);
    image!.dispose();
  });

  test('garbage bytes give null instead of throwing', () async {
    final p = OpenFreeMapTileProvider(
        client: MockClient((r) async => r.url.toString() == kOpenFreeMapTileJsonUrl
            ? http.Response(_tileJson, 200)
            : http.Response.bytes(utf8.encode('not a tile'), 200)),
        loadAsset: _asset);
    expect(await p.tile(14, 8675, 5426, ui.Brightness.light), isNull);
  });

  test('a hung request times out to null', () async {
    final p = OpenFreeMapTileProvider(
      client: MockClient((r) => Future.delayed(const Duration(seconds: 5),
          () => http.Response(_tileJson, 200))),
      loadAsset: _asset,
      timeout: const Duration(milliseconds: 50),
    );
    expect(await p.tile(14, 8675, 5426, ui.Brightness.light), isNull);
  });
}
```

- [ ] **Step 3: Run, expect FAIL** — `flutter test test/map/openfreemap_tile_provider_test.dart` → compile error: `openfreemap_tile_provider.dart` not found.

- [ ] **Step 4: Implement** — `lib/map/openfreemap_tile_provider.dart`:

```dart
import 'dart:async' show TimeoutException;
import 'dart:collection';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import 'openfreemap.dart';
import 'preview_projection.dart' show previewPixelRatio;
import 'preview_snapshot.dart';

/// Draws OpenFreeMap vector tiles for the preview snapshot renderer (Spec 19
/// §B): TileJSON → versioned URL, overzoom above the data's maxzoom, parse
/// off the UI isolate, paint with the bundled style minus raster/3D layers.
/// Any failure is `null`: the preview is marked stale and retried later.
class OpenFreeMapTileProvider implements PreviewTileProvider {
  OpenFreeMapTileProvider({
    http.Client? client,
    Future<String> Function(String asset)? loadAsset,
    this.pixelRatio = previewPixelRatio,
    this.timeout = const Duration(seconds: 8),
    this.cacheSize = 24,
  })  : _client = client ?? http.Client(),
        _loadAsset = loadAsset ?? rootBundle.loadString;

  final http.Client _client;
  final Future<String> Function(String asset) _loadAsset;
  final double pixelRatio;

  /// Per-request deadline; a hung request must not stall the whole snapshot.
  final Duration timeout;

  /// Parsed tiles kept in memory: rides in one area share them.
  final int cacheSize;

  Future<TileJson>? _tileJson;
  final _themes = <ui.Brightness, Future<vtr.Theme>>{};
  final _tiles = LinkedHashMap<String, Future<vtr.VectorTile>>();

  @override
  Future<ui.Image?> tile(int z, int x, int y, ui.Brightness brightness) async {
    try {
      final tileJson = await _resolveTileJson();
      final source = overzoomTile(z, x, y, maxZoom: tileJson.maxZoom);
      final vectorTile = await _vectorTile(tileJson, source);
      final theme = await _theme(brightness);
      return _paint(vectorTile, theme, source, z);
    } catch (_) {
      return null;
    }
  }

  Future<TileJson> _resolveTileJson() => _tileJson ??= () async {
        try {
          final res = await _get(Uri.parse(kOpenFreeMapTileJsonUrl));
          if (res.statusCode != 200) throw http.ClientException('TileJSON ${res.statusCode}');
          return parseTileJson(res.body);
        } catch (_) {
          _tileJson = null; // retried by the next tile
          rethrow;
        }
      }();

  Future<vtr.VectorTile> _vectorTile(TileJson tileJson, OverzoomTile source) {
    final key = '${source.z}/${source.x}/${source.y}';
    final cached = _tiles.remove(key);
    if (cached != null) return _tiles[key] = cached; // most recently used
    final loading = () async {
      final res = await _get(tileUrl(tileJson.template, source.z, source.x, source.y));
      if (res.statusCode == 404) _tileJson = null; // weekly data version moved on
      if (res.statusCode != 200) throw http.ClientException('tile ${res.statusCode}');
      final bytes = res.bodyBytes;
      return Isolate.run(() => vtr.VectorTileReader().read(bytes));
    }();
    _tiles[key] = loading;
    loading.catchError((Object _) {
      if (identical(_tiles[key], loading)) _tiles.remove(key);
      return vtr.VectorTile(layers: const []);
    });
    while (_tiles.length > cacheSize) {
      _tiles.remove(_tiles.keys.first);
    }
    return loading;
  }

  Future<vtr.Theme> _theme(ui.Brightness brightness) =>
      _themes[brightness] ??= () async {
        final asset = brightness == ui.Brightness.dark
            ? kRetrailDarkStyleAsset
            : kLibertyStyleAsset;
        final style = jsonDecode(await _loadAsset(asset)) as Map<String, dynamic>;
        return vtr.ThemeReader().read(previewStyle(style));
      }();

  Future<ui.Image> _paint(
      vtr.VectorTile vectorTile, vtr.Theme theme, OverzoomTile source, int z) async {
    final tile = vtr.TileFactory(theme, const vtr.Logger.noop())
        .createTileData(vectorTile)
        .toTile();
    final px = (kPreviewTileDp * pixelRatio).round();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.scale(pixelRatio * source.scale);
    canvas.translate(-source.left, -source.top);
    vtr.Renderer(theme: theme).render(
      canvas,
      vtr.TileSource(tileset: vtr.Tileset({kOpenFreeMapSource: tile})),
      clip: source.scale == 1
          ? null
          : ui.Rect.fromLTWH(source.left, source.top, source.size, source.size),
      zoomScaleFactor: source.scale.toDouble(),
      zoom: z.toDouble(),
      rotation: 0,
    );
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(px, px);
    } finally {
      picture.dispose();
    }
  }

  Future<http.Response> _get(Uri url) async {
    try {
      return await _client.get(url, headers: const {'User-Agent': kMapUserAgent}).timeout(timeout);
    } on TimeoutException {
      throw http.ClientException('timeout', url);
    }
  }
}
```

Notes for the implementer: `vtr.VectorTile` is re-exported by `vector_tile_renderer`; if its constructor differs, drop the `catchError` return value by using `loading.then((_) {}, onError: (_) { … })` instead — the point is only to evict a failed future. Keep `Uint8List` import only if the analyzer needs it.

- [ ] **Step 5: Run, expect PASS** — `flutter test test/map/openfreemap_tile_provider_test.dart`.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/map/openfreemap_tile_provider.dart test/map/openfreemap_tile_provider_test.dart test/fixtures/map/14_8675_5426.pbf
git commit -m "feat(map): draw preview tiles from openfreemap vector tiles (#58)"
```

---

### Task 4: Wire the previews to OpenFreeMap, drop the MapTiler provider

**Files:**
- Modify: `lib/features/active_ride/active_ride_providers.dart:8-9,39`, `lib/map/route_preview_cache.dart:25-30`, `lib/map/preview_projection.dart:24-35`, `test/map/preview_projection_test.dart:114-115`
- Delete: `lib/map/maptiler_tile_provider.dart`, `test/map/maptiler_tile_provider_test.dart`

**Interfaces:**
- Consumes: `OpenFreeMapTileProvider()` (Task 3).

- [ ] **Step 1: Write the failing test** — add to `test/map/route_preview_cache_test.dart`:

```dart
  test('previews live in ride_previews_v7 (Spec 19: every preview re-renders '
      'with OpenFreeMap)', () {
    final cache = RoutePreviewCache(
        baseDir: Directory('/tmp/x'),
        render: (_, _) async => PreviewResult(Uint8List(0), complete: true));
    expect(cache.fileFor(1, brightness: Brightness.light).path,
        '/tmp/x/ride_previews_v7/1.png');
  });
```

(Use the file's existing imports; add `dart:io`, `dart:typed_data`, `dart:ui show Brightness` and `preview_snapshot.dart show PreviewResult` if missing.)

- [ ] **Step 2: Run, expect FAIL** — `flutter test test/map/route_preview_cache_test.dart` → path is `…_v6/1.png`.

- [ ] **Step 3: Implement**
  - `route_preview_cache.dart`: `const int _cacheVersion = 7;` and append to the doc comment: `/// v7 — OpenFreeMap vector tiles replace MapTiler raster tiles (Spec 19).`
  - `active_ride_providers.dart`: replace the imports `../../map/map_config.dart` and `../../map/maptiler_tile_provider.dart` by `../../map/openfreemap_tile_provider.dart`; replace `final tiles = MapTilerTileProvider(apiKey: MapConfig.mapTilerKey);` by `final tiles = OpenFreeMapTileProvider();`.
  - `preview_projection.dart`: rewrite the `previewPixelRatio` doc so it no longer mentions MapTiler: the basemap is now drawn as vectors at this ratio too, so it is crisp at any density up to 3.0.
  - `test/map/preview_projection_test.dart:114-115`: update the comment the same way (no MapTiler).
  - `git rm lib/map/maptiler_tile_provider.dart test/map/maptiler_tile_provider_test.dart`.

- [ ] **Step 4: Verify** — `flutter analyze` clean (no dangling import of the deleted file); `flutter test` green.

- [ ] **Step 5: Commit**

```bash
git add -A lib/features/active_ride/active_ride_providers.dart lib/map test/map
git commit -m "feat(map): previews render from openfreemap, cache v7 (#58)"
```

---

### Task 5: Live map style (Liberty URL / bundled Retrail Dark)

**Files:**
- Modify: `lib/map/live_map.dart:80-82` (style function), `_LiveMapState` (`didChangeDependencies` ~1116, `build` ~1175), `test/map/live_map_style_test.dart`
- Delete: `lib/map/map_style.dart`; in `lib/map/map_config.dart` remove `mapTilerKey`, `vectorStyleUrl`, `mapTilerCopyright` (keep `osmCopyright`; Task 6 adds `openMapTilesCopyright`)

**Interfaces:**
- Consumes: `kLibertyStyleUrl`, `kRetrailDarkStyleAsset` (Task 2).
- Produces: `String? liveMapStyle(bool dark, {String? darkStyleJson})` (null = dark style not loaded yet); `Future<String> loadRetrailDarkStyle(AssetBundle bundle)`.

- [ ] **Step 1: Write the failing tests** — replace `test/map/live_map_style_test.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/map/live_map.dart';
import 'package:retrail/map/openfreemap.dart';

class _Bundle extends CachingAssetBundle {
  final loaded = <String>[];
  @override
  Future<ByteData> load(String key) => throw UnimplementedError();
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    loaded.add(key);
    return '{"version":8}';
  }
}

void main() {
  group('liveMapStyle', () {
    test('light mode loads OpenFreeMap Liberty by URL', () {
      expect(liveMapStyle(false), kLibertyStyleUrl);
    });
    test('dark mode hands the bundled Retrail Dark JSON to MapLibre', () {
      expect(liveMapStyle(true, darkStyleJson: '{"version":8}'), '{"version":8}');
    });
    test('dark mode before the JSON has loaded: no style yet', () {
      expect(liveMapStyle(true), isNull);
    });
  });

  test('loadRetrailDarkStyle reads the bundled asset', () async {
    final bundle = _Bundle();
    expect(await loadRetrailDarkStyle(bundle), '{"version":8}');
    expect(bundle.loaded, [kRetrailDarkStyleAsset]);
  });
}
```

- [ ] **Step 2: Run, expect FAIL** — `flutter test test/map/live_map_style_test.dart` → `liveMapStyle` / `loadRetrailDarkStyle` undefined.

- [ ] **Step 3: Implement in `lib/map/live_map.dart`**
  - Replace `String liveMapStyleUrl(bool dark) => MapConfig.vectorStyleUrl(dark);` and its doc with:

```dart
/// The live map's MapLibre style (Spec 19 §A): OpenFreeMap Liberty by URL in
/// light mode, the bundled Retrail Dark JSON in dark mode (MapLibre takes a
/// URL or a JSON string). Null while the dark JSON hasn't loaded yet.
String? liveMapStyle(bool dark, {String? darkStyleJson}) =>
    dark ? darkStyleJson : kLibertyStyleUrl;

/// Reads the bundled Retrail Dark style for the live map.
Future<String> loadRetrailDarkStyle(AssetBundle bundle) =>
    bundle.loadString(kRetrailDarkStyleAsset);
```

  - Imports: add `import 'package:flutter/services.dart' show AssetBundle;` (if `material.dart` doesn't already export it) and `import 'openfreemap.dart';`; remove `import 'map_config.dart';` if nothing else in the file uses `MapConfig`.
  - In `_LiveMapState` add the field and load it once in `didChangeDependencies` (before the brightness handling):

```dart
  /// The bundled Retrail Dark style, loaded once; the dark map waits for it
  /// behind its placeholder.
  String? _darkStyleJson;
  bool _darkStyleRequested = false;
```

```dart
    if (!_darkStyleRequested) {
      _darkStyleRequested = true;
      loadRetrailDarkStyle(DefaultAssetBundle.of(context)).then((json) {
        if (mounted) setState(() => _darkStyleJson = json);
      });
    }
```

  - In `build`, compute `final initStyle = liveMapStyle(dark, darkStyleJson: _darkStyleJson);` next to `final dark = …`, then make the map conditional inside the `Stack` children: `if (initStyle != null) MapLibreMap(…, options: MapOptions(initStyle: initStyle, …))`. The placeholder stays (`covered` is true until the style loads anyway).
  - `git rm lib/map/map_style.dart`; in `lib/map/map_config.dart` delete `mapTilerKey`, `vectorStyleUrl`, `mapTilerCopyright` and the class doc about the key; the class keeps `osmCopyright`.

- [ ] **Step 4: Verify** — `flutter test test/map/live_map_style_test.dart` passes; `flutter analyze` clean; `flutter test` green (`map_attribution.dart` still references `MapConfig.mapTilerCopyright` → it is replaced in Task 6; if Task 6 is not done yet, keep `mapTilerCopyright` until then and delete it in Task 6).

- [ ] **Step 5: Commit**

```bash
git add -A lib/map test/map/live_map_style_test.dart
git commit -m "feat(map): live map on openfreemap liberty and bundled retrail dark (#58)"
```

---

### Task 6: Credit — OpenMapTiles + OSM, collapsing to ⓘ once per app start

**Files:**
- Modify: `lib/map/map_attribution.dart`, `lib/map/map_config.dart`, `lib/l10n/app_en.arb`, `lib/l10n/app_de.arb`, `lib/features/active_ride/widgets/ride_chrome.dart`, `lib/features/history/ride_detail_dialog.dart`, `test/map/map_attribution_test.dart`, `test/active_ride/ride_map_area_test.dart`, `test/history/history_dialogs_test.dart`

**Interfaces:**
- Produces:

```dart
class MapCreditSession { bool expandedShown = false; }
final mapCreditSessionProvider = Provider<MapCreditSession>((ref) => MapCreditSession());
class MapAttribution extends ConsumerStatefulWidget {
  const MapAttribution({super.key, this.onOpen, this.collapsible = false});
  final ValueChanged<Uri>? onOpen;
  final bool collapsible;
}
const Duration kMapCreditCollapseDelay = Duration(seconds: 5);
```
- `MapConfig.openMapTilesCopyright` = `Uri.parse('https://openmaptiles.org/')`; `MapConfig.osmCopyright` unchanged.

- [ ] **Step 1: ARB** — in both `app_en.arb` and `app_de.arb` replace `"mapAttributionMapTiler": "© MapTiler",` by `"mapAttributionOpenMapTiles": "© OpenMapTiles",`; set `"mapAttributionOsm": "© OpenStreetMap",` in both; add `"mapCreditsCd": "Map credits",` (en) / `"mapCreditsCd": "Kartenquellen",` (de). Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing tests** — replace `test/map/map_attribution_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/l10n/app_localizations.dart';
import 'package:retrail/map/map_attribution.dart';
import 'package:retrail/map/map_config.dart';

Widget _host(Widget child, {Locale? locale, ProviderContainer? container}) =>
    UncontrolledProviderScope(
      container: container ?? ProviderContainer(),
      child: MaterialApp(
        locale: locale,
        theme: buildTheme(Brightness.light),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Stack(children: [
            const Positioned(top: 0, left: 0, child: SizedBox(key: Key('elsewhere'), width: 50, height: 50)),
            Center(child: child),
          ]),
        ),
      ),
    );

final _info = find.byIcon(Icons.info_outline);

void main() {
  testWidgets('credits OpenMapTiles and OpenStreetMap (EN)', (tester) async {
    await tester.pumpWidget(_host(const MapAttribution()));
    expect(find.text('© OpenMapTiles'), findsOneWidget);
    expect(find.text('© OpenStreetMap'), findsOneWidget);
  });

  testWidgets('German: the same short credit', (tester) async {
    await tester.pumpWidget(_host(const MapAttribution(), locale: const Locale('de')));
    expect(find.text('© OpenMapTiles'), findsOneWidget);
    expect(find.text('© OpenStreetMap'), findsOneWidget);
  });

  testWidgets('with onOpen: each credit opens its page', (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(_host(MapAttribution(onOpen: opened.add)));
    await tester.tap(find.text('© OpenMapTiles'));
    await tester.tap(find.text('© OpenStreetMap'));
    expect(opened, [MapConfig.openMapTilesCopyright, MapConfig.osmCopyright]);
  });

  testWidgets('without onOpen: plain text, no tap targets', (tester) async {
    await tester.pumpWidget(_host(const MapAttribution()));
    expect(find.descendant(of: find.byType(MapAttribution), matching: find.byType(GestureDetector)),
        findsNothing);
  });

  testWidgets('not collapsible: stays expanded past 5 s', (tester) async {
    await tester.pumpWidget(_host(const MapAttribution()));
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('© OpenStreetMap'), findsOneWidget);
    expect(_info, findsNothing);
  });

  group('collapsible', () {
    testWidgets('the first credit after app start shows expanded, then '
        'collapses to ⓘ after 5 s', (tester) async {
      await tester.pumpWidget(_host(const MapAttribution(collapsible: true)));
      expect(find.text('© OpenStreetMap'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('© OpenStreetMap'), findsNothing);
      expect(_info, findsOneWidget);
    });

    testWidgets('a later credit in the same app start starts as ⓘ', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(_host(const MapAttribution(collapsible: true), container: container));
      await tester.pumpWidget(_host(const SizedBox(), container: container));
      await tester.pumpWidget(_host(const MapAttribution(collapsible: true), container: container));
      expect(find.text('© OpenStreetMap'), findsNothing);
      expect(_info, findsOneWidget);
    });

    testWidgets('a touch outside collapses it at once', (tester) async {
      await tester.pumpWidget(_host(const MapAttribution(collapsible: true)));
      await tester.tap(find.byKey(const Key('elsewhere')), warnIfMissed: false);
      await tester.pump();
      expect(_info, findsOneWidget);
    });

    testWidgets('tapping a link while expanded opens it and does not collapse '
        'first', (tester) async {
      final opened = <Uri>[];
      await tester.pumpWidget(_host(MapAttribution(collapsible: true, onOpen: opened.add)));
      await tester.tap(find.text('© OpenStreetMap'));
      await tester.pump();
      expect(opened, [MapConfig.osmCopyright]);
      expect(find.text('© OpenStreetMap'), findsOneWidget);
    });

    testWidgets('tapping ⓘ expands it again; it collapses again after 5 s',
        (tester) async {
      await tester.pumpWidget(_host(const MapAttribution(collapsible: true)));
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(_info);
      await tester.pump();
      expect(find.text('© OpenStreetMap'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(_info, findsOneWidget);
    });

    testWidgets('a rebuild of the same credit keeps its state', (tester) async {
      await tester.pumpWidget(_host(const MapAttribution(collapsible: true)));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(_host(const MapAttribution(collapsible: true)));
      expect(_info, findsOneWidget);
    });

    testWidgets('the ⓘ is announced as "Map credits"', (tester) async {
      final container = ProviderContainer()..read(mapCreditSessionProvider).expandedShown = true;
      addTearDown(container.dispose);
      await tester.pumpWidget(_host(const MapAttribution(collapsible: true), container: container));
      expect(find.byTooltip('Map credits'), findsOneWidget);
    });
  });
}
```

Note on "a rebuild keeps its state": `_host` builds a new `ProviderContainer()` each call when none is passed; `UncontrolledProviderScope` with a new container is a different widget config but the same element position, so the `MapAttribution` state survives. If it doesn't (the scope swap recreates the subtree), pass one shared container in that test.

- [ ] **Step 3: Run, expect FAIL** — `flutter test test/map/map_attribution_test.dart` → `collapsible` / `mapCreditSessionProvider` / `openMapTilesCopyright` undefined.

- [ ] **Step 4: Implement** — `lib/map/map_config.dart`: replace `mapTilerCopyright` by

```dart
  static final Uri openMapTilesCopyright = Uri.parse('https://openmaptiles.org/');
```

and remove `mapTilerKey`/`vectorStyleUrl` if Task 5 left them. Then rewrite `lib/map/map_attribution.dart`:

```dart
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_shapes.dart';
import '../core/theme/theme_context.dart';
import '../l10n/app_localizations.dart';
import 'map_config.dart';

/// Opens a map credit's page in the browser — the [MapAttribution] `onOpen`
/// of every interactive map.
void openMapCopyright(Uri page) => launchUrl(page, mode: LaunchMode.externalApplication);

/// Whether this app start has shown an expanded collapsible credit yet
/// (Spec 19 §C). A plain flag: nothing watches it.
class MapCreditSession {
  bool expandedShown = false;
}

final mapCreditSessionProvider = Provider<MapCreditSession>((ref) => MapCreditSession());

/// How long a collapsible credit stays expanded without a touch.
const Duration kMapCreditCollapseDelay = Duration(seconds: 5);

/// Gap between a map's bottom edge and its [MapAttribution].
const double kMapAttributionInset = 4.0;

/// The "© OpenMapTiles © OpenStreetMap" credit the OpenMapTiles (CC BY) and
/// OSM licences require on every map; the `maplibre` package hides the
/// native attribution control, so the screens draw this one.
///
/// With [onOpen] each credit is tappable. [collapsible] (live maps): the
/// first one after an app start shows expanded and collapses to an ⓘ after
/// [kMapCreditCollapseDelay] or a touch outside it; later ones start as ⓘ
/// (the OSMF guidelines allow both). Tapping ⓘ expands it again.
class MapAttribution extends ConsumerStatefulWidget {
  const MapAttribution({super.key, this.onOpen, this.collapsible = false});

  final ValueChanged<Uri>? onOpen;
  final bool collapsible;

  @override
  ConsumerState<MapAttribution> createState() => _MapAttributionState();
}

class _MapAttributionState extends ConsumerState<MapAttribution> {
  bool _expanded = true;
  Timer? _collapseTimer;

  @override
  void initState() {
    super.initState();
    if (!widget.collapsible) return;
    final session = ref.read(mapCreditSessionProvider);
    _expanded = !session.expandedShown;
    session.expandedShown = true;
    if (_expanded) _scheduleCollapse();
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    if (widget.collapsible) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    }
    super.dispose();
  }

  void _scheduleCollapse() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(kMapCreditCollapseDelay, _collapse);
  }

  void _collapse() {
    _collapseTimer?.cancel();
    if (mounted && _expanded) setState(() => _expanded = false);
  }

  void _expand() {
    setState(() => _expanded = true);
    _scheduleCollapse();
  }

  /// Any touch outside the credit collapses it; touches on it (its links)
  /// must land first.
  void _onPointer(PointerEvent event) {
    if (event is! PointerDownEvent || !_expanded) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return;
    final local = box.globalToLocal(event.position);
    if (!(Offset.zero & box.size).contains(local)) _collapse();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    if (!_expanded) {
      return Material(
        color: colors.surface.withValues(alpha: _backgroundAlpha),
        shape: const CircleBorder(),
        child: IconButton(
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          tooltip: l10n.mapCreditsCd,
          onPressed: _expand,
          icon: Icon(Icons.info_outline, color: colors.onSurfaceVariant),
        ),
      );
    }
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant);

    Widget credit(String label, Uri page) {
      final text = Text(label, style: style);
      final open = widget.onOpen;
      return open == null
          ? text
          : GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => open(page), child: text);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: _backgroundAlpha),
        borderRadius: AppShapes.input,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Wrap(
          spacing: 4,
          alignment: WrapAlignment.center,
          children: [
            credit(l10n.mapAttributionOpenMapTiles, MapConfig.openMapTilesCopyright),
            credit(l10n.mapAttributionOsm, MapConfig.osmCopyright),
          ],
        ),
      ),
    );
  }
}

/// Enough to read the credit over busy tiles, light enough to see the map.
const double _backgroundAlpha = 0.75;
```

- [ ] **Step 5: Hosts** — `ride_chrome.dart`: `MapAttribution(onOpen: openMapCopyright, collapsible: true)`; `ride_detail_dialog.dart` `_MapCredit`: same. The history card keeps `MapAttribution()` (plain, not collapsible).
  - The credit in `ride_chrome.dart` is centred in a full-width `Positioned`; the collapsed ⓘ then sits bottom-centre — fine (between the corner controls).
  - Tests: `ride_map_area_test.dart` `pumpArea` and `history_dialogs_test.dart` `_host` wrap their `MaterialApp` in `ProviderScope(child: …)`; in `ride_map_area_test.dart` extend `'credits the map tiles, tappable'` with `expect(credit.collapsible, isTrue);` and in `history_dialogs_test.dart` the dialog test checks `collapsible` is true in dialog and fullscreen; `history_screen_test.dart`'s card test checks `credits.single.collapsible` is false.
  - The fullscreen toggle moves the map but builds a new `_MapCredit`: it starts as ⓘ (later credit in the same app start) — that is the intended behaviour.

- [ ] **Step 6: Verify** — `flutter test test/map/map_attribution_test.dart test/active_ride/ride_map_area_test.dart test/history` green; then `flutter analyze` and full `flutter test`.

- [ ] **Step 7: Commit**

```bash
git add lib/map lib/l10n lib/features test/map test/active_ride test/history
git commit -m "feat(map): credit openmaptiles and osm, collapse to an info button (#58)"
```

---

### Task 7: Remove the MapTiler build plumbing, update docs and the privacy policy

**Files:**
- Modify: `.github/workflows/ios-build.yml:59-61` (+ header comment lines 4-7), `.gitignore:27-28`, `docs/android-release.md:79`, `docs/ios-sideloading.md:28,192,211`, `CLAUDE.md` (tech stack "Tile source", "Map previews", "Testing" if needed), `lib/map/CLAUDE.md` (live map bullet, map credit bullet, ride previews bullet), `site/privacy/index.html` (section 4 DE + EN, both "Stand"/"Last updated"), `docs/specs/19-openfreemap.md` (status → IMPLEMENTED once the device check passes)

- [ ] **Step 1: CI** — `ios-build.yml`: delete the `env: MAPTILER_KEY` block and `--dart-define=MAPTILER_KEY="$MAPTILER_KEY"` so the step reads `run: flutter build ios --release --no-codesign`. Header comment: replace "and the MapTiler key is compiled into the app" with "and the build is a full app" — the encryption reason stays (any signed-in user can download artifacts of a public repo).
- [ ] **Step 2: `.gitignore`** — delete the two lines `# Secrets — MapTiler API key…` and `maptiler.json`.
- [ ] **Step 3: Docs** — `docs/android-release.md`: build command `flutter build appbundle --release`. `docs/ios-sideloading.md`: remove the `MAPTILER_KEY` bullet and its table entry (keep `IPA_PASSWORD`), rewrite line 211 to "AES-encrypted and only kept for 3 days." `CLAUDE.md`: Tile source row → `**OpenFreeMap** (free, no key): live map Liberty by URL + bundled Retrail Dark (assets/map/, \`tool/build_map_styles.dart\`); previews draw the same vector tiles with \`vector_tile_renderer\` (Spec 19)`. Update the "Maps (live)"/"Map previews" rows if they name MapTiler. `lib/map/CLAUDE.md`: replace every MapTiler description (style names, `@2x` raster previews, `MapTilerTileProvider`, credit text) with the Spec 19 behaviour: `OpenFreeMapTileProvider`, overzoom from z14, isolate parse, LRU, 404 → TileJSON re-resolve, `_cacheVersion` 7, credit collapsing once per app start via `mapCreditSessionProvider`.
- [ ] **Step 4: Privacy policy** — `site/privacy/index.html` section 4, German:

```html
<h2>4. Kartendienst (OpenFreeMap)</h2>
<p>Um die Karte anzuzeigen, lädt die App Kartendaten („Kacheln“), Kartenstile, Schriften und Symbole vom kostenlosen Dienst <strong>OpenFreeMap</strong> (<code>tiles.openfreemap.org</code>, ausgeliefert über das Netzwerk von Cloudflare). Dabei werden technisch notwendig übermittelt: deine <strong>IP-Adresse</strong>, Informationen zur App/zum Gerät (User-Agent) und der angefragte Kartenausschnitt – aus diesem lässt sich ungefähr ablesen, welche Gegend du dir gerade ansiehst. Deine aufgezeichneten Strecken werden nicht übermittelt. OpenFreeMap verwendet nach eigenen Angaben keine Konten und keine Cookies.</p>
<p>Rechtsgrundlage ist Art. 6 Abs. 1 lit. f DSGVO (berechtigtes Interesse an der Darstellung einer Karte). Nutzungsbedingungen von OpenFreeMap: <a href="https://openfreemap.org/tos/">openfreemap.org/tos</a>.</p>
```

English:

```html
<h2>4. Map service (OpenFreeMap)</h2>
<p>To show the map, the app loads map data (“tiles”), map styles, fonts and icons from the free service <strong>OpenFreeMap</strong> (<code>tiles.openfreemap.org</code>, served through Cloudflare's network). This technically requires transmitting your <strong>IP address</strong>, app/device information (user agent) and the requested map area — which roughly shows which area you are looking at. Your recorded routes are not transmitted. According to OpenFreeMap, it uses no accounts and no cookies.</p>
<p>Legal basis: Art. 6(1)(f) GDPR (legitimate interest in showing a map). OpenFreeMap's terms: <a href="https://openfreemap.org/tos/">openfreemap.org/tos</a>.</p>
```

Set "Stand"/"Last updated" to the merge date.
- [ ] **Step 5: Verify** — `grep -rni maptiler lib .github docs/android-release.md docs/ios-sideloading.md CLAUDE.md lib/map/CLAUDE.md site .gitignore` → no output. `flutter analyze` clean, `flutter test` green, `flutter build appbundle --release` succeeds without `--dart-define`.
- [ ] **Step 6: Commit**

```bash
git add -A .github .gitignore docs CLAUDE.md lib/map/CLAUDE.md site
git commit -m "chore(map): remove the maptiler key and docs, privacy policy on openfreemap (#58)"
```

---

### Task 8: Device acceptance and integration

- [ ] **Step 1: Install on the Pixel 7** — `flutter run --profile -d 27181FDH2001C8` (no `--dart-define`).
- [ ] **Step 2: Check with the user, light and dark, EN and DE:** live map Liberty / Retrail Dark (labels readable, grass green); ride / follow map credit expanded on the first map after a cold start, collapses after 5 s and on touch, later maps start as ⓘ, ⓘ reopens it, links open; history previews re-render after the update (labels, overzoom on a short ride, no visible scroll jank during the catch-up); airplane mode → sketch preview, back online → map preview. Tune `tool/build_map_styles.dart` colours if needed (re-run the generator, keep Task 1's test in sync).
- [ ] **Step 3: Final review** — whole-branch review (subagent on the most capable model), fix findings or file them as GitHub issues.
- [ ] **Step 4: Spec status** — `docs/specs/19-openfreemap.md`: `**Status:** IMPLEMENTED — device check passed on <date>.`; commit `docs: spec 19 implemented (#58)`.
- [ ] **Step 5: Integrate** — `git rebase main`, `git checkout main && git merge --ff-only phase/19-openfreemap`, `git branch -d phase/19-openfreemap`. **Ask the user before pushing** (the push also publishes the privacy policy via Pages and triggers the iOS build). After the push: enable Pages (Settings → Pages → Source: GitHub Actions, or `gh api -X POST repos/Valijuu/Retrail/pages -f build_type=workflow`), check `https://valijuu.github.io/Retrail/privacy/`, wait for the iOS build to go green, ask the user to delete the `MAPTILER_KEY` repo secret, close #58 and update #45.
