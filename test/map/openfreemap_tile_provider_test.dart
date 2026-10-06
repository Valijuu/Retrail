import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:retrail/map/openfreemap.dart';
import 'package:retrail/map/openfreemap_tile_provider.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

const _tileJson =
    '{"tiles":["https://t.example/planet/v1/{z}/{x}/{y}.pbf"],"maxzoom":14}';
final _pbf = File('test/fixtures/map/14_8675_5426.pbf').readAsBytesSync();

/// A town tile with street names (Wernigerode old town, public OSM data).
final _townPbf = File('test/fixtures/map/14_8682_5424.pbf').readAsBytesSync();

/// Bundled styles from disk (the provider loads them through [loadAsset]).
Future<String> _asset(String path) async => File(path).readAsString();

class _Server {
  final requests = <http.Request>[];
  int tileJsonCalls = 0;
  int Function(Uri tile)? tileStatus;
  bool tileJsonFails = false;

  /// The tile body served; null = the Brocken fixture.
  List<int>? tileBytes;

  MockClient get client => MockClient((r) async {
    requests.add(r);
    if (r.url.toString() == kOpenFreeMapTileJsonUrl) {
      tileJsonCalls++;
      if (tileJsonFails) return http.Response('down', 503);
      return http.Response(_tileJson, 200);
    }
    final status = tileStatus?.call(r.url) ?? 200;
    return status == 200
        ? http.Response.bytes(tileBytes ?? _pbf, 200)
        : http.Response('', status);
  });

  List<Uri> get tileUrls => [
    for (final r in requests)
      if (r.url.toString() != kOpenFreeMapTileJsonUrl) r.url,
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

  test('draws the tile\'s map features, not a flat background', () async {
    final s = _Server();
    final image = await provider(s).tile(14, 8675, 5426, ui.Brightness.light);
    final bytes = await image!.toByteData();
    image.dispose();
    final pixels = bytes!.buffer.asUint32List();
    expect(
      pixels.toSet().length,
      greaterThan(10),
      reason:
          'roads, woods and labels give many colours; a style that '
          'matches no source layer paints only the background',
    );
  });

  /// [_pbf] painted the way the provider paints a z14 tile, with [zoom] for
  /// the style and [painter] for labels.
  Future<List<int>> reference(double zoom, vtr.TextPainterProvider painter,
      {List<int>? pbf}) async {
    final style = previewStyle(
        jsonDecode(await _asset(kRetrailLightStyleAsset)) as Map<String, dynamic>);
    final theme = vtr.ThemeReader().read(style);
    final tile = vtr.TileFactory(theme, const vtr.Logger.noop())
        .createTileData(vtr.VectorTileReader().read(
            Uint8List.fromList(pbf ?? _pbf)))
        .toTile();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..scale(3);
    vtr.Renderer(theme: theme, painterProvider: painter).render(canvas,
        vtr.TileSource(tileset: vtr.Tileset({kOpenFreeMapSource: tile})),
        zoomScaleFactor: 1, zoom: zoom, rotation: 0);
    final image = await recorder.endRecording().toImage(768, 768);
    final bytes = await image.toByteData();
    image.dispose();
    return bytes!.buffer.asUint8List();
  }

  Future<List<int>> providerTile({List<int>? pbf}) async {
    final server = _Server()..tileBytes = pbf;
    final image =
        await provider(server).tile(14, 8675, 5426, ui.Brightness.light);
    final bytes = (await image!.toByteData())!.buffer.asUint8List();
    image.dispose();
    return bytes;
  }

  const scaled = PreviewTextPainterProvider(kPreviewLabelScale);

  test('styles a tile one zoom level below its grid zoom: MapLibre styles '
      'assume 512 px tiles, the preview grid is 256 dp, so line widths and '
      'label sizes match the live map instead of looking a level too big',
      () async {
    final bytes = await providerTile();
    expect(bytes, isNot(equals(await reference(14, scaled))));
    expect(bytes, equals(await reference(13, scaled)));
  });

  test('draws labels smaller than the style says (kPreviewLabelScale): the '
      'small preview is shown stretched across the card', () async {
    final bytes = await providerTile(pbf: _townPbf);
    expect(bytes, isNot(equals(await reference(13,
        const vtr.DefaultTextPainterProvider(), pbf: _townPbf))));
    expect(bytes, equals(await reference(13, scaled, pbf: _townPbf)));
  });

  test(
    'fetches the versioned URL from TileJSON with the Retrail user agent',
    () async {
      final s = _Server();
      (await provider(s).tile(14, 8675, 5426, ui.Brightness.dark))?.dispose();
      expect(s.tileUrls, [
        Uri.parse('https://t.example/planet/v1/14/8675/5426.pbf'),
      ]);
      expect(
        s.requests.every((r) => r.headers['User-Agent'] == kMapUserAgent),
        isTrue,
      );
    },
  );

  test('resolves TileJSON once for many tiles', () async {
    final s = _Server();
    final p = provider(s);
    (await p.tile(14, 8675, 5426, ui.Brightness.light))?.dispose();
    (await p.tile(14, 8676, 5426, ui.Brightness.light))?.dispose();
    expect(s.tileJsonCalls, 1);
  });

  test(
    'a z16 grid tile draws from its z14 parent, fetched once for all four',
    () async {
      final s = _Server();
      final p = provider(s);
      final images = await Future.wait([
        for (final (x, y) in [
          (34700, 21704),
          (34701, 21704),
          (34700, 21705),
          (34701, 21705),
        ])
          p.tile(16, x, y, ui.Brightness.light),
      ]);
      expect(images.every((i) => i != null && i.width == 768), isTrue);
      for (final i in images) {
        i!.dispose();
      }
      expect(s.tileUrls, [
        Uri.parse('https://t.example/planet/v1/14/8675/5426.pbf'),
      ]);
    },
  );

  test('both themes share one fetched tile', () async {
    final s = _Server();
    final p = provider(s);
    (await p.tile(14, 8675, 5426, ui.Brightness.light))?.dispose();
    (await p.tile(14, 8675, 5426, ui.Brightness.dark))?.dispose();
    expect(s.tileUrls, hasLength(1));
  });

  test(
    'a 404 (data version moved on) gives null and re-resolves TileJSON',
    () async {
      final s = _Server()..tileStatus = (_) => 404;
      final p = provider(s);
      expect(await p.tile(14, 8675, 5426, ui.Brightness.light), isNull);
      s.tileStatus = null;
      (await p.tile(14, 8676, 5426, ui.Brightness.light))?.dispose();
      expect(s.tileJsonCalls, 2);
    },
  );

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
      client: MockClient(
        (r) async => r.url.toString() == kOpenFreeMapTileJsonUrl
            ? http.Response(_tileJson, 200)
            : http.Response.bytes(utf8.encode('not a tile'), 200),
      ),
      loadAsset: _asset,
    );
    expect(await p.tile(14, 8675, 5426, ui.Brightness.light), isNull);
  });

  test('a hung request times out to null', () async {
    final p = OpenFreeMapTileProvider(
      client: MockClient(
        (r) => Future.delayed(
          const Duration(seconds: 5),
          () => http.Response(_tileJson, 200),
        ),
      ),
      loadAsset: _asset,
      timeout: const Duration(milliseconds: 50),
    );
    expect(await p.tile(14, 8675, 5426, ui.Brightness.light), isNull);
  });
}
