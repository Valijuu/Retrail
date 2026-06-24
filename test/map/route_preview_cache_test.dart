import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/map/preview_projection.dart';
import 'package:retrail/map/route_preview_cache.dart';

void main() {
  late Directory tempDir;

  setUp(() => tempDir = Directory.systemTemp.createTempSync('preview_cache'));
  tearDown(() => tempDir.deleteSync(recursive: true));

  const points = <RoutePoint>[(lat: 1, lng: 2), (lat: 3, lng: 4)];

  test('generates the file once and reuses it', () async {
    var renders = 0;
    final cache = RoutePreviewCache(
      baseDir: tempDir,
      render: (_) async {
        renders++;
        return Uint8List.fromList([1, 2, 3]);
      },
    );

    final first = await cache.ensurePreview(7, points);
    expect(await first.exists(), isTrue);
    expect(renders, 1);

    final second = await cache.ensurePreview(7, points);
    expect(second.path, first.path);
    expect(renders, 1); // reused, not re-rendered
  });

  test('evict deletes the cached file', () async {
    final cache = RoutePreviewCache(
      baseDir: tempDir,
      render: (_) async => Uint8List.fromList([9]),
    );
    final file = await cache.ensurePreview(3, points);
    expect(await file.exists(), isTrue);

    await cache.evict(3);
    expect(await file.exists(), isFalse);
  });
}
