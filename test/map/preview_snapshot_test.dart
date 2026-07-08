import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/map/preview_projection.dart';
import 'package:retrail/map/preview_snapshot.dart';

Future<ui.Image> _solid(int size, ui.Color color) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
      ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      ui.Paint()..color = color);
  return recorder.endRecording().toImage(size, size);
}

class _FakeTiles implements PreviewTileProvider {
  @override
  Future<ui.Image?> tile(int z, int x, int y, ui.Brightness b) =>
      _solid(256, const ui.Color(0xFFDDDDDD));
}

class _NoTiles implements PreviewTileProvider {
  @override
  Future<ui.Image?> tile(int z, int x, int y, ui.Brightness b) async => null;
}

/// Fails exactly one tile (the first requested) — a realistic network flake.
class _FlakyTiles implements PreviewTileProvider {
  int _calls = 0;

  @override
  Future<ui.Image?> tile(int z, int x, int y, ui.Brightness b) =>
      _calls++ == 0 ? Future.value(null) : _solid(256, const ui.Color(0xFFDDDDDD));
}

const _points = <RoutePoint>[
  (lat: 49.440, lng: 11.080),
  (lat: 49.445, lng: 11.105),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('renders a valid, complete PNG at the requested pixel size', () async {
    final result = await renderPreviewPng(
      points: _points,
      widthDp: 100,
      heightDp: 80,
      pixelRatio: 2,
      tiles: _FakeTiles(),
      brightness: ui.Brightness.light,
    );
    expect(result.bytes, isNotEmpty);
    expect(result.complete, isTrue); // every tile decoded
    final codec = await ui.instantiateImageCodec(result.bytes);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, 200);
    expect(frame.image.height, 160);
  });

  test('renders even when tiles are unavailable, but flags it incomplete',
      () async {
    final result = await renderPreviewPng(
      points: _points,
      widthDp: 100,
      heightDp: 80,
      pixelRatio: 1,
      tiles: _NoTiles(),
      brightness: ui.Brightness.dark,
    );
    expect(result.bytes, isNotEmpty); // terrain background still renders
    expect(result.complete, isFalse); // must be regenerated, never cached final
  });

  test('a single failed tile flags the snapshot incomplete', () async {
    final result = await renderPreviewPng(
      points: _points,
      widthDp: 100,
      heightDp: 80,
      pixelRatio: 1,
      tiles: _FlakyTiles(),
      brightness: ui.Brightness.light,
    );
    expect(result.bytes, isNotEmpty);
    expect(result.complete, isFalse); // one hole → stale, retried later
  });

  test('the offline sketch is always incomplete (upgraded when online)',
      () async {
    final result = await renderSketchPng(
      points: _points,
      widthDp: 100,
      heightDp: 80,
      pixelRatio: 1,
      brightness: ui.Brightness.light,
    );
    expect(result.bytes, isNotEmpty);
    expect(result.complete, isFalse);
  });
}
