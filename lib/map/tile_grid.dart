import 'dart:math' as math;

import 'preview_projection.dart';

/// One raster tile in a preview grid: its `z/x/y` and its top-left pixel offset
/// (dp) within the slot.
class TileRef {
  const TileRef({
    required this.z,
    required this.x,
    required this.y,
    required this.offsetXDp,
    required this.offsetYDp,
  });

  final int z;
  final int x;
  final int y;
  final double offsetXDp;
  final double offsetYDp;
}

/// Tile size in pixels at integer zoom (Web Mercator).
const int tileSize = 256;

/// Computes the 1–6 raster tiles covering [f]'s slot, ported from the original
/// `TileBackdrop`. Longitude tiles wrap at the antimeridian; latitude tiles
/// outside `[0, 2^z)` (near the poles) are skipped.
List<TileRef> tilesFor(StaticFraming f) {
  final z = f.zoom.toInt();
  final cx = lonXAtZoom(f.centerLon, z.toDouble());
  final cy = latYAtZoom(f.centerLat, z.toDouble());
  final left = cx - f.widthDp / 2.0;
  final right = cx + f.widthDp / 2.0;
  final top = cy - f.heightDp / 2.0;
  final bottom = cy + f.heightDp / 2.0;

  final txMin = (left / tileSize).floor();
  final txMax = (right / tileSize).floor();
  final tyMin = (top / tileSize).floor();
  final tyMax = (bottom / tileSize).floor();
  final tilesPerAxis = math.pow(2, z).toInt();

  final tiles = <TileRef>[];
  for (var tx = txMin; tx <= txMax; tx++) {
    for (var ty = tyMin; ty <= tyMax; ty++) {
      if (ty < 0 || ty >= tilesPerAxis) continue;
      final safeTx = ((tx % tilesPerAxis) + tilesPerAxis) % tilesPerAxis;
      tiles.add(TileRef(
        z: z,
        x: safeTx,
        y: ty,
        offsetXDp: tx * tileSize - left,
        offsetYDp: ty * tileSize - top,
      ));
    }
  }
  return tiles;
}
