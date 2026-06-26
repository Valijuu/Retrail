import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/features/active_ride/preview_renderer.dart';
import 'package:retrail/map/preview_projection.dart';

void main() {
  final points = <RoutePoint>[(lat: 1.0, lng: 2.0), (lat: 1.1, lng: 2.1)];

  test('online routes to the snapshot renderer', () async {
    String? which;
    final render = buildPreviewRenderer(
      isOnline: () => true,
      online: (p) async {
        which = 'online';
        return Uint8List(0);
      },
      offline: (p) async {
        which = 'offline';
        return Uint8List(0);
      },
    );
    await render(points);
    expect(which, 'online');
  });

  test('offline routes to the sketch renderer', () async {
    String? which;
    final render = buildPreviewRenderer(
      isOnline: () => false,
      online: (p) async {
        which = 'online';
        return Uint8List(0);
      },
      offline: (p) async {
        which = 'offline';
        return Uint8List(0);
      },
    );
    await render(points);
    expect(which, 'offline');
  });

  test('passes the route points through to the chosen renderer', () async {
    List<RoutePoint>? seen;
    final render = buildPreviewRenderer(
      isOnline: () => true,
      online: (p) async {
        seen = p;
        return Uint8List(0);
      },
      offline: (p) async => Uint8List(0),
    );
    await render(points);
    expect(seen, points);
  });
}
