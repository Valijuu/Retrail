import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Brightness;

import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/map/preview_projection.dart';
import 'package:retrail/map/preview_snapshot.dart';
import 'package:retrail/map/route_preview_cache.dart';

PreviewResult _png(List<int> bytes, {bool complete = true}) =>
    PreviewResult(Uint8List.fromList(bytes), complete: complete);

void main() {
  late Directory tempDir;

  setUp(() => tempDir = Directory.systemTemp.createTempSync('preview_cache'));
  tearDown(() => tempDir.deleteSync(recursive: true));

  const points = <RoutePoint>[(lat: 1, lng: 2), (lat: 3, lng: 4)];

  test('purgeOutdatedVersions deletes older preview dirs, keeps the current '
      'one and anything unrelated', () async {
    final cache =
        RoutePreviewCache(baseDir: tempDir, render: (_, _) async => _png([1]));
    await cache.ensurePreview(7, points, brightness: Brightness.light);
    final current = cache.fileFor(7, brightness: Brightness.light).parent;
    final old4 = Directory('${tempDir.path}/ride_previews_v4')..createSync();
    final old5 = Directory('${tempDir.path}/ride_previews_v5')..createSync();
    File('${old5.path}/7.png').writeAsBytesSync([1]);
    final unrelated = Directory('${tempDir.path}/ride_previews_backup')
      ..createSync();
    final dbFile = File('${tempDir.path}/retrail.sqlite')..writeAsBytesSync([1]);

    await cache.purgeOutdatedVersions();

    expect(old4.existsSync(), isFalse);
    expect(old5.existsSync(), isFalse);
    expect(current.existsSync(), isTrue);
    expect(unrelated.existsSync(), isTrue);
    expect(dbFile.existsSync(), isTrue);
  });

  test('generates the file once per brightness and reuses it', () async {
    var renders = 0;
    final cache = RoutePreviewCache(
      baseDir: tempDir,
      render: (_, _) async {
        renders++;
        return _png([1, 2, 3]);
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
      render: (_, b) async => _png([b == Brightness.dark ? 1 : 0]),
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
      render: (_, _) async => _png([9]),
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

  test('an incomplete render is served but marked stale and re-rendered '
      'next time; a complete re-render clears the mark', () async {
    var renders = 0;
    var completeNow = false; // first render offline/holey, then online
    final cache = RoutePreviewCache(
      baseDir: tempDir,
      render: (_, _) async {
        renders++;
        return _png([renders], complete: completeNow);
      },
    );

    // 1st call: incomplete (e.g. offline sketch) → written + stale-marked.
    final file =
        await cache.ensurePreview(7, points, brightness: Brightness.light);
    expect(await file.exists(), isTrue);
    expect(renders, 1);
    expect(
        await cache.staleMarkerFor(7, brightness: Brightness.light).exists(),
        isTrue);

    // 2nd call, now "online": re-renders, upgrades the PNG, clears the marker.
    completeNow = true;
    await cache.ensurePreview(7, points, brightness: Brightness.light);
    expect(renders, 2);
    expect(await file.readAsBytes(), [2]); // upgraded bytes
    expect(
        await cache.staleMarkerFor(7, brightness: Brightness.light).exists(),
        isFalse);

    // 3rd call: complete + unmarked → cached fast path, no re-render.
    await cache.ensurePreview(7, points, brightness: Brightness.light);
    expect(renders, 2);
  });

  test('upgrading a stale preview to a complete render announces the ride on '
      '`upgrades` — a first complete render does not (issue #31)', () async {
    var completeNow = false;
    final cache = RoutePreviewCache(
      baseDir: tempDir,
      render: (_, _) async => _png([1], complete: completeNow),
    );
    final announced = <int>[];
    final sub = cache.upgrades.listen(announced.add);
    addTearDown(sub.cancel);

    await cache.ensurePreview(7, points, brightness: Brightness.light); // stale
    completeNow = true;
    await cache.ensurePreview(8, points, brightness: Brightness.light); // fresh
    await cache.ensurePreview(7, points, brightness: Brightness.light); // upgrade
    await pumpEventQueue();
    expect(announced, [7]);
  });

  test('a stale preview that re-renders incomplete stays stale and keeps '
      'its existing bytes (no pointless rewrite)', () async {
    var renders = 0;
    final cache = RoutePreviewCache(
      baseDir: tempDir,
      render: (_, _) async {
        renders++;
        return _png([renders], complete: false);
      },
    );

    final file =
        await cache.ensurePreview(4, points, brightness: Brightness.dark);
    await cache.ensurePreview(4, points, brightness: Brightness.dark);
    expect(renders, 2); // stale → retried
    expect(await file.readAsBytes(), [1]); // same sketch — first write kept
    expect(
        await cache.staleMarkerFor(4, brightness: Brightness.dark).exists(),
        isTrue);
  });

  test('resolvedFileFor is null until a complete render, then synchronous',
      () async {
    final cache = RoutePreviewCache(
      baseDir: tempDir,
      render: (_, _) async => _png([1]),
    );
    expect(cache.resolvedFileFor(7, brightness: Brightness.light), isNull);

    final file =
        await cache.ensurePreview(7, points, brightness: Brightness.light);
    expect(cache.resolvedFileFor(7, brightness: Brightness.light)?.path,
        file.path); // known synchronously → jank-free list builds
    // Other variant still unknown.
    expect(cache.resolvedFileFor(7, brightness: Brightness.dark), isNull);
  });

  test('an incomplete (stale) render is never memoized as resolved', () async {
    final cache = RoutePreviewCache(
      baseDir: tempDir,
      render: (_, _) async => _png([1], complete: false),
    );
    await cache.ensurePreview(7, points, brightness: Brightness.light);
    expect(cache.resolvedFileFor(7, brightness: Brightness.light), isNull);
  });

  test('evict clears the resolved memo', () async {
    final cache = RoutePreviewCache(
      baseDir: tempDir,
      render: (_, _) async => _png([1]),
    );
    await cache.ensurePreview(7, points, brightness: Brightness.light);
    await cache.evict(7);
    expect(cache.resolvedFileFor(7, brightness: Brightness.light), isNull);
  });

  test('renders are bounded to maxConcurrentRenders — queued, not fanned '
      'out unboundedly, but not fully serial either (issue #23)', () async {
    var active = 0, maxActive = 0;
    final cache = RoutePreviewCache(
      baseDir: tempDir,
      maxConcurrentRenders: 3,
      render: (_, _) async {
        active++;
        maxActive = active > maxActive ? active : maxActive;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        active--;
        return _png([1]);
      },
    );
    // A fast scroll (or a bulk-seeded backlog) kicks off many previews at once.
    await Future.wait([
      for (var id = 1; id <= 9; id++)
        cache.ensurePreview(id, points, brightness: Brightness.light),
    ]);
    expect(maxActive, 3); // capped at the configured lane count…
    expect(maxActive, greaterThan(1)); // …but actually running some in parallel
  });

  test('maxConcurrentRenders defaults to 3', () async {
    var maxActive = 0, active = 0;
    final cache = RoutePreviewCache(
      baseDir: tempDir,
      render: (_, _) async {
        active++;
        maxActive = active > maxActive ? active : maxActive;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        active--;
        return _png([1]);
      },
    );
    await Future.wait([
      for (var id = 1; id <= 9; id++)
        cache.ensurePreview(id, points, brightness: Brightness.light),
    ]);
    expect(maxActive, 3);
  });

  test('evict removes stale markers too', () async {
    final cache = RoutePreviewCache(
      baseDir: tempDir,
      render: (_, _) async => _png([1], complete: false),
    );
    await cache.ensurePreview(9, points, brightness: Brightness.light);
    expect(
        await cache.staleMarkerFor(9, brightness: Brightness.light).exists(),
        isTrue);

    await cache.evict(9);
    expect(
        await cache.staleMarkerFor(9, brightness: Brightness.light).exists(),
        isFalse);
  });
}
