import 'dart:async' show TimeoutException;
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;

import 'map_style.dart';
import 'preview_snapshot.dart';

/// Fetches MapTiler raster tiles for the preview snapshot renderer.
class MapTilerTileProvider implements PreviewTileProvider {
  MapTilerTileProvider({
    required this.apiKey,
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  /// Per-tile fetch deadline. Without it one hung request stalls the whole
  /// snapshot's `Future.wait`; timing out to `null` instead flags the preview
  /// incomplete → stale → retried on a later view.
  final Duration timeout;

  @override
  Future<ui.Image?> tile(int z, int x, int y, ui.Brightness brightness) async {
    final mapId = MapStyle.mapId(brightness == ui.Brightness.dark);
    // `@2x` (512px) tiles match the snapshot's 2.0 pixel-ratio canvas
    // (`_previewPixelRatio` in active_ride_providers) — 1x tiles would be
    // upscaled 2× into the PNG and look blurry.
    final url =
        'https://api.maptiler.com/maps/$mapId/$z/$x/$y@2x.png?key=$apiKey';
    try {
      final response = await _client.get(Uri.parse(url)).timeout(timeout);
      if (response.statusCode != 200) return null;
      final codec = await ui.instantiateImageCodec(response.bodyBytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
