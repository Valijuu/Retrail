import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Brightness;

import 'preview_projection.dart';

/// Produces the preview PNG bytes for a route at a given [Brightness]. The app
/// composes this from the snapshot renderer (online) or the flat sketch
/// (offline) — see Spec 12 wiring.
typedef PreviewRenderer = Future<Uint8List> Function(
    List<RoutePoint> points, Brightness brightness);

/// Disk cache of ride-preview PNGs, keyed by `rideId` **and brightness** (light
/// + dark variants coexist). Generated once per variant (at save or first view)
/// so list scrolling never fetches tiles, and the card always matches the
/// current theme — mirroring the original, whose live preview followed the app
/// theme.
class RoutePreviewCache {
  RoutePreviewCache({required this.baseDir, required this.render});

  final Directory baseDir;
  final PreviewRenderer render;

  File fileFor(int rideId, {required Brightness brightness}) {
    final suffix = brightness == Brightness.dark ? '_dark' : '';
    // `_v3`: the basemap now matches the live map (topo-v2) and the start/end
    // dots gained a white halo — a new directory forces existing rides to
    // re-render in the new style instead of serving the old streets-v2 PNG.
    return File('${baseDir.path}/ride_previews_v3/$rideId$suffix.png');
  }

  /// Returns the cached preview file for [brightness], rendering + writing it
  /// once if missing.
  Future<File> ensurePreview(int rideId, List<RoutePoint> points,
      {required Brightness brightness}) async {
    final file = fileFor(rideId, brightness: brightness);
    if (await file.exists()) return file;
    final bytes = await render(points, brightness);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Deletes both cached variants (on ride edit/delete), so neither theme serves
  /// a stale preview.
  Future<void> evict(int rideId) async {
    for (final brightness in Brightness.values) {
      final file = fileFor(rideId, brightness: brightness);
      if (await file.exists()) await file.delete();
    }
  }
}
