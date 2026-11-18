import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/map/preview_projection.dart';
import 'package:retrail/map/preview_snapshot.dart';
import 'package:retrail/map/route_preview.dart';
import 'package:retrail/map/route_preview_cache.dart';

void main() {
  late Directory tempDir;

  setUp(() => tempDir = Directory.systemTemp.createTempSync('route_preview'));
  tearDown(() => tempDir.deleteSync(recursive: true));

  const points = <RoutePoint>[(lat: 1, lng: 2), (lat: 3, lng: 4)];

  testWidgets('a failed render is retried once and then shows the image, '
      'never a card that stays blank (#88)', (tester) async {
    var renders = 0;
    final cache = RoutePreviewCache(
      baseDir: tempDir,
      render: (_, _) async {
        renders++;
        if (renders == 1) throw const FileSystemException('lost the race');
        return PreviewResult(Uint8List.fromList([1, 2, 3]), complete: true);
      },
    );
    addTearDown(cache.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: RoutePreview(
          rideId: 2,
          hasRoute: true,
          pointsLoader: () async => points,
          cache: cache,
        ),
      ),
    );
    for (var i = 0; i < 20 && find.byType(Image).evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }

    expect(renders, 2);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('a card shows the preview of the new cache when the language '
      'changes (#128)', (tester) async {
    RoutePreviewCache cacheOf(String language, int byte) => RoutePreviewCache(
      baseDir: tempDir,
      language: language,
      render: (_, _) async =>
          PreviewResult(Uint8List.fromList([byte]), complete: true),
    );
    final english = cacheOf('en', 1);
    final german = cacheOf('de', 2);
    addTearDown(english.dispose);
    addTearDown(german.dispose);

    // One RoutePreview whose cache is swapped in place: the same State sees
    // the language change through didUpdateWidget, as a card in the list does.
    final active = ValueNotifier<RoutePreviewCache>(english);
    addTearDown(active.dispose);
    final app = MaterialApp(
      theme: buildTheme(Brightness.light),
      home: ValueListenableBuilder<RoutePreviewCache>(
        valueListenable: active,
        builder: (_, cache, _) => RoutePreview(
          rideId: 3,
          hasRoute: true,
          pointsLoader: () async => points,
          cache: cache,
        ),
      ),
    );

    Future<void> settle() async {
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
    }

    await tester.pumpWidget(app);
    await settle();
    active.value = german;
    await tester.pump();
    await settle();

    final shown = tester.widget<Image>(find.byType(Image)).image as FileImage;
    expect(shown.file.path, contains('ride_previews_v18_de'));
  });
}
