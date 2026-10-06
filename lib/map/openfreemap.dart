/// OpenFreeMap (Spec 19): tile and style locations plus the pure helpers the
/// preview tile provider and the live map share.
library;

import 'dart:convert';

/// OpenFreeMap's TileJSON: the current, versioned tile URL and the data's
/// maxzoom.
const String kOpenFreeMapTileJsonUrl = 'https://tiles.openfreemap.org/planet';

/// The live map's light style, loaded by URL so it picks up OpenFreeMap's
/// fixes and sprite/glyph versions.
const String kLibertyStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';

/// Bundled styles (`tool/build_map_styles.dart`): Liberty for light previews,
/// Retrail Dark for the dark live map and dark previews.
const String kLibertyStyleAsset = 'assets/map/liberty.json';
const String kRetrailDarkStyleAsset = 'assets/map/retrail_dark.json';

/// The vector source name in the OpenFreeMap styles.
const String kOpenFreeMapSource = 'openmaptiles';

/// Sent with every OpenFreeMap request: a free service, so the app says who
/// it is (some agents are rejected).
const String kMapUserAgent = 'Retrail (io.github.valijuu.retrail)';

/// TileJSON key holding the list of tile URL templates.
const _tileJsonTilesKey = 'tiles';

/// TileJSON key holding the highest zoom level the tiles exist for.
const _tileJsonMaxZoomKey = 'maxzoom';

const _missingTilesMessage = 'TileJSON: no tiles';
const _missingMaxZoomMessage = 'TileJSON: no maxzoom';

/// Placeholders a TileJSON tile URL template carries for zoom, column and row.
const _zoomPlaceholder = '{z}';
const _columnPlaceholder = '{x}';
const _rowPlaceholder = '{y}';

/// Side of a preview grid tile in dp (`tile_grid.dart`'s `tileSize`); the
/// coordinate space [OverzoomTile]'s square is measured in.
const int kPreviewTileDp = 256;

/// The parts of an OpenFreeMap TileJSON document the app needs.
class TileJson {
  const TileJson({required this.template, required this.maxZoom});

  /// Versioned tile URL template, e.g. `…/planet/20260927_080001_pt/{z}/{x}/{y}.pbf`.
  final String template;

  /// Highest zoom level tiles exist for; deeper zooms overzoom a parent tile.
  final int maxZoom;
}

/// Parses a TileJSON [body] into its first tile template and max zoom.
///
/// Throws a [FormatException] when `tiles` is missing or empty, or when
/// `maxzoom` is missing or not a number.
TileJson parseTileJson(String body) {
  final json = jsonDecode(body) as Map<String, dynamic>;
  final tiles = json[_tileJsonTilesKey];
  if (tiles is! List || tiles.isEmpty) {
    throw const FormatException(_missingTilesMessage);
  }
  final maxZoom = json[_tileJsonMaxZoomKey];
  if (maxZoom is! num) throw const FormatException(_missingMaxZoomMessage);
  return TileJson(template: tiles.first as String, maxZoom: maxZoom.toInt());
}

/// The URL of tile `z/x/y` from a TileJSON [template].
Uri tileUrl(String template, int z, int x, int y) => Uri.parse(
  template
      .replaceAll(_zoomPlaceholder, '$z')
      .replaceAll(_columnPlaceholder, '$x')
      .replaceAll(_rowPlaceholder, '$y'),
);

/// The tile to fetch for a requested tile beyond the data's max zoom, and the
/// part of it the requested tile covers.
class OverzoomTile {
  const OverzoomTile({
    required this.z,
    required this.x,
    required this.y,
    required this.scale,
    required this.left,
    required this.top,
    required this.size,
  });

  /// Zoom, column and row of the tile to fetch (the requested tile's ancestor
  /// at max zoom, or the requested tile itself at or below it).
  final int z, x, y;

  /// How many times the fetched tile is magnified: 2^(requested z - fetched z).
  final int scale;

  /// The square inside the fetched tile, in its [kPreviewTileDp]-unit space,
  /// that the requested tile covers.
  final double left, top, size;
}

/// Maps tile `z/x/y` onto the tile that exists for it when the vector data
/// stops at [maxZoom]; at or below [maxZoom] that is the tile itself.
OverzoomTile overzoomTile(int z, int x, int y, {required int maxZoom}) {
  final zoomsPastMax = z > maxZoom ? z - maxZoom : 0;
  final scale = 1 << zoomsPastMax;
  final size = kPreviewTileDp / scale;
  return OverzoomTile(
    z: z - zoomsPastMax,
    x: x >> zoomsPastMax,
    y: y >> zoomsPastMax,
    scale: scale,
    left: (x % scale) * size,
    top: (y % scale) * size,
    size: size,
  );
}

/// Style JSON key holding the ordered list of layers.
const _styleLayersKey = 'layers';

/// Layer JSON key holding the layer's type.
const _layerTypeKey = 'type';

/// Layer types a preview never draws: `raster` (Natural Earth shading) and
/// `fill-extrusion` (3D buildings).
const Set<String> _previewDroppedLayerTypes = {'raster', 'fill-extrusion'};

/// A copy of the MapLibre [style] without the layers a preview never draws
/// (see [_previewDroppedLayerTypes]); every other layer, labels included,
/// keeps its order. [style] itself is not changed.
Map<String, dynamic> previewStyle(Map<String, dynamic> style) => {
  ...style,
  _styleLayersKey: [
    for (final layer in style[_styleLayersKey] as List)
      if (!_previewDroppedLayerTypes.contains((layer as Map)[_layerTypeKey]))
        layer,
  ],
};
