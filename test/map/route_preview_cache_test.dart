import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Brightness;

import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/map/preview_projection.dart';
import 'package:retrail/map/route_preview_cache.dart';

void main() {
  late Directory tempDir;

  setUp(() => tempDir = Directory.systemTemp.createTempSync('preview_cache'));
  tearDown(() => tempDir.deleteSync(recursive: true));

  const points = <RoutePoint>[(lat: 1, lng: 2), (lat: 3, lng: 4)];

  test('generates the file once per brightness and reuses it', () async {
    var renders = 0;
    final cache = RoutePreviewCache(
      baseDir: tempDir,
      render: (_, _) async {
        renders++;
        return Uint8List.fromList([1, 2, 3]);
      },
    );

    final first =
        await cache.ensurePreview(7, points, brightness: Brightness.light);
    expect(await first.exists(), isTrue);
    expect(renders, 1);

    final second =
        await cache.ensurePreview(7, points, brightness: Brightness.light);
    expect(second.path, first.path);
    expect(renders, 1); // reused, not re-rendered
  });

  test('light and dark are cached as distinct files that coexist', () async {
    final cache = RoutePreviewCache(
      baseDir: tempDir,
      // Render brightness-dependent bytes so the variants are distinguishable.
      render: (_, b) async =>
          Uint8List.fromList([b == Brightness.dark ? 1 : 0]),
    );

    final light =
        await cache.ensurePreview(5, points, brightness: Brightness.light);
    final dark =
        await cache.ensurePreview(5, points, brightness: Brightness.dark);

    expect(light.path, isNot(dark.path)); // keyed by brightness, not just id
    expect(await light.exists(), isTrue);
    expect(await dark.exists(), isTrue); // both survive
    expect(await light.readAsBytes(), [0]);
    expect(await dark.readAsBytes(), [1]);
  });

  test('evict deletes BOTH the light and dark cached files', () async {
    final cache = RoutePreviewCache(
      baseDir: tempDir,
      render: (_, _) async => Uint8List.fromList([9]),
    );
    final light =
        await cache.ensurePreview(3, points, brightness: Brightness.light);
    final dark =
        await cache.ensurePreview(3, points, brightness: Brightness.dark);
    expect(await light.exists(), isTrue);
    expect(await dark.exists(), isTrue);

    await cache.evict(3);
    expect(await light.exists(), isFalse);
    expect(await dark.exists(), isFalse);
  });
}
