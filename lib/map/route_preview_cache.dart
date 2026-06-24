import 'dart:io';
import 'dart:typed_data';

import 'preview_projection.dart';

/// Produces the preview PNG bytes for a route. The app composes this from the
/// snapshot renderer (online) or the flat sketch (offline) — see Spec 12 wiring.
typedef PreviewRenderer = Future<Uint8List> Function(List<RoutePoint> points);

/// Disk cache of ride-preview PNGs, keyed by `rideId`. Generated once (at save
/// or first view) so list scrolling never fetches tiles.
class RoutePreviewCache {
  RoutePreviewCache({required this.baseDir, required this.render});

  final Directory baseDir;
  final PreviewRenderer render;

  File fileFor(int rideId) =>
      File('${baseDir.path}/ride_previews/$rideId.png');

  /// Returns the cached preview file, rendering + writing it once if missing.
  Future<File> ensurePreview(int rideId, List<RoutePoint> points) async {
    final file = fileFor(rideId);
    if (await file.exists()) return file;
    final bytes = await render(points);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Deletes the cached file (on ride edit/delete). The widget layer also evicts
  /// the corresponding `FileImage` from Flutter's image cache.
  Future<void> evict(int rideId) async {
    final file = fileFor(rideId);
    if (await file.exists()) await file.delete();
  }
}
