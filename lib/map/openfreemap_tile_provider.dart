import 'dart:async' show TimeoutException;
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
  }) : _client = client ?? http.Client(),
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
  final _tiles = <String, Future<vtr.VectorTile>>{}; // insertion-ordered: LRU

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
      if (res.statusCode != 200) {
        throw http.ClientException('TileJSON ${res.statusCode}');
      }
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
      final res = await _get(
        tileUrl(tileJson.template, source.z, source.x, source.y),
      );
      // A 404: the weekly data version moved on, so resolve TileJSON again.
      if (res.statusCode == 404) _tileJson = null;
      if (res.statusCode != 200) {
        throw http.ClientException('tile ${res.statusCode}');
      }
      return _parseOffUiIsolate(res.bodyBytes);
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
            : kRetrailLightStyleAsset;
        final style =
            jsonDecode(await _loadAsset(asset)) as Map<String, dynamic>;
        return vtr.ThemeReader().read(previewStyle(style));
      }();

  Future<ui.Image> _paint(
    vtr.VectorTile vectorTile,
    vtr.Theme theme,
    OverzoomTile source,
    int z,
  ) async {
    final tile = vtr.TileFactory(
      theme,
      const vtr.Logger.noop(),
    ).createTileData(vectorTile).toTile();
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
      return await _client
          .get(url, headers: const {'User-Agent': kMapUserAgent})
          .timeout(timeout);
    } on TimeoutException {
      throw http.ClientException('timeout', url);
    }
  }
}

/// Parses a pbf tile on a background isolate. Top-level so the closure sent
/// to the isolate captures only [bytes] (a closure inside the provider would
/// drag its pending futures along, which can't be sent).
Future<vtr.VectorTile> _parseOffUiIsolate(Uint8List bytes) =>
    Isolate.run(() => vtr.VectorTileReader().read(bytes));
