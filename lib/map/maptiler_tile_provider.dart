import 'dart:ui' as ui;

import 'package:http/http.dart' as http;

import 'map_style.dart';
import 'preview_snapshot.dart';

/// Fetches MapTiler raster tiles for the preview snapshot renderer.
class MapTilerTileProvider implements PreviewTileProvider {
  MapTilerTileProvider({required this.apiKey, http.Client? client})
      : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  @override
  Future<ui.Image?> tile(int z, int x, int y, ui.Brightness brightness) async {
    final mapId = MapStyle.mapId(brightness == ui.Brightness.dark);
    final url =
        'https://api.maptiler.com/maps/$mapId/$z/$x/$y.png?key=$apiKey';
    try {
      final response = await _client.get(Uri.parse(url));
      if (response.statusCode != 200) return null;
      final codec = await ui.instantiateImageCodec(response.bodyBytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }
}
