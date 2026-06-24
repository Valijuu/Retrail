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

const _points = <RoutePoint>[
  (lat: 49.440, lng: 11.080),
  (lat: 49.445, lng: 11.105),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('renders a valid PNG at the requested pixel size', () async {
    final bytes = await renderPreviewPng(
      points: _points,
      widthDp: 100,
      heightDp: 80,
      pixelRatio: 2,
      tiles: _FakeTiles(),
      brightness: ui.Brightness.light,
    );
    expect(bytes, isNotEmpty);
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, 200);
    expect(frame.image.height, 160);
  });

  test('renders even when tiles are unavailable (terrain background)', () async {
    final bytes = await renderPreviewPng(
      points: _points,
      widthDp: 100,
      heightDp: 80,
      pixelRatio: 1,
      tiles: _NoTiles(),
      brightness: ui.Brightness.dark,
    );
    expect(bytes, isNotEmpty);
  });
}
