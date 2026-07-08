import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:retrail/map/maptiler_tile_provider.dart';

/// A tiny real PNG (1×1) so the decode path runs against valid bytes.
Future<Uint8List> _onePxPng() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
      const ui.Rect.fromLTWH(0, 0, 1, 1), ui.Paint()..color = const ui.Color(0xFF112233));
  final image = await recorder.endRecording().toImage(1, 1);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('requests hi-dpi @2x tiles for the style matching the brightness',
      () async {
    final png = await _onePxPng();
    Uri? requested;
    final provider = MapTilerTileProvider(
      apiKey: 'test-key',
      client: MockClient((request) async {
        requested = request.url;
        return http.Response.bytes(png, 200);
      }),
    );

    final image = await provider.tile(14, 8722, 5678, ui.Brightness.light);

    expect(image, isNotNull);
    // @2x: 512px tiles matching the snapshot's pixelRatio 2.0 — no upscaling.
    expect(requested.toString(),
        'https://api.maptiler.com/maps/topo-v2/14/8722/5678@2x.png?key=test-key');
  });

  test('dark brightness requests the dark style', () async {
    final png = await _onePxPng();
    Uri? requested;
    final provider = MapTilerTileProvider(
      apiKey: 'k',
      client: MockClient((request) async {
        requested = request.url;
        return http.Response.bytes(png, 200);
      }),
    );

    await provider.tile(3, 1, 2, ui.Brightness.dark);
    expect(requested!.path, contains('basic-v2-dark'));
  });

  test('a non-200 response yields null (renderer flags the tile missing)',
      () async {
    final provider = MapTilerTileProvider(
      apiKey: 'k',
      client: MockClient((_) async => http.Response('rate limited', 429)),
    );
    expect(await provider.tile(3, 1, 2, ui.Brightness.light), isNull);
  });

  test('a hung request times out to null instead of stalling the preview',
      () async {
    final provider = MapTilerTileProvider(
      apiKey: 'k',
      timeout: const Duration(milliseconds: 50),
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        return http.Response('too late', 200);
      }),
    );
    expect(await provider.tile(3, 1, 2, ui.Brightness.light), isNull);
  });

  test('undecodable bytes yield null', () async {
    final provider = MapTilerTileProvider(
      apiKey: 'k',
      client: MockClient((_) async => http.Response('not a png', 200)),
    );
    expect(await provider.tile(3, 1, 2, ui.Brightness.light), isNull);
  });
}
