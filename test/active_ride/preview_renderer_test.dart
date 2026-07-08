import 'dart:typed_data';
import 'dart:ui' show Brightness;

import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/features/active_ride/preview_renderer.dart';
import 'package:retrail/map/preview_projection.dart';
import 'package:retrail/map/preview_snapshot.dart';

PreviewResult _empty({bool complete = true}) =>
    PreviewResult(Uint8List(0), complete: complete);

void main() {
  final points = <RoutePoint>[(lat: 1.0, lng: 2.0), (lat: 1.1, lng: 2.1)];

  test('online routes to the snapshot renderer', () async {
    String? which;
    final render = buildPreviewRenderer(
      isOnline: () => true,
      online: (p, b) async {
        which = 'online';
        return _empty();
      },
      offline: (p, b) async {
        which = 'offline';
        return _empty(complete: false);
      },
    );
    await render(points, Brightness.light);
    expect(which, 'online');
  });

  test('offline routes to the sketch renderer', () async {
    String? which;
    final render = buildPreviewRenderer(
      isOnline: () => false,
      online: (p, b) async {
        which = 'online';
        return _empty();
      },
      offline: (p, b) async {
        which = 'offline';
        return _empty(complete: false);
      },
    );
    await render(points, Brightness.light);
    expect(which, 'offline');
  });

  test('passes the route points through to the chosen renderer', () async {
    List<RoutePoint>? seen;
    final render = buildPreviewRenderer(
      isOnline: () => true,
      online: (p, b) async {
        seen = p;
        return _empty();
      },
      offline: (p, b) async => _empty(complete: false),
    );
    await render(points, Brightness.light);
    expect(seen, points);
  });

  test('passes the requested brightness through to the renderer', () async {
    Brightness? seen;
    final render = buildPreviewRenderer(
      isOnline: () => true,
      online: (p, b) async {
        seen = b;
        return _empty();
      },
      offline: (p, b) async => _empty(complete: false),
    );
    await render(points, Brightness.dark);
    expect(seen, Brightness.dark); // dark mode → dark snapshot
  });

  test('propagates the renderer\'s completeness (stale sketch stays stale)',
      () async {
    final render = buildPreviewRenderer(
      isOnline: () => false,
      online: (p, b) async => _empty(),
      offline: (p, b) async => _empty(complete: false),
    );
    final result = await render(points, Brightness.light);
    expect(result.complete, isFalse);
  });
}
