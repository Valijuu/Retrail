import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/heading.dart' show LatLng;
import 'package:retrail/features/history_map/map_locator.dart';
import 'package:retrail/features/history_map/outline_fill.dart';

class _FakeLocator implements MapLocator {
  final controller = StreamController<LatLng>.broadcast();

  @override
  Future<LocateResult> locate() async => const LocateDenied();

  @override
  Stream<LatLng> positions() => controller.stream;

  @override
  Future<void> openAppSettings() async {}
}

class _Foreground extends AppForegroundNotifier {
  _Foreground(this.value);
  final bool value;

  @override
  bool build() => value;
}

void main() {
  late _FakeLocator locator;

  ProviderContainer container({bool foreground = true}) {
    final c = ProviderContainer(
      overrides: [
        mapLocatorProvider.overrideWithValue(locator),
        appForegroundProvider.overrideWith(() => _Foreground(foreground)),
      ],
    );
    addTearDown(c.dispose);
    c.listen(positionFeedProvider, (_, _) {});
    return c;
  }

  setUp(() => locator = _FakeLocator());
  tearDown(() => locator.controller.close());

  test('no position is read before location was allowed', () async {
    final c = container();
    c.read(mapVisibleProvider.notifier).set(true);
    expect(locator.controller.hasListener, isFalse);
  });

  test('the stream runs while allowed, visible and in front', () async {
    final c = container();
    c.read(locationEnabledProvider.notifier).enable();
    c.read(mapVisibleProvider.notifier).set(true);
    await pumpEventQueue();
    expect(locator.controller.hasListener, isTrue);
    locator.controller.add((lat: 1.0, lng: 2.0));
    await pumpEventQueue();
    expect(c.read(mapPositionProvider), (lat: 1.0, lng: 2.0));
  });

  test('the stream stops when the map is hidden', () async {
    final c = container();
    c.read(locationEnabledProvider.notifier).enable();
    c.read(mapVisibleProvider.notifier).set(true);
    c.read(mapVisibleProvider.notifier).set(false);
    await pumpEventQueue();
    expect(locator.controller.hasListener, isFalse);
  });

  test('the stream does not run in the background', () async {
    final c = container(foreground: false);
    c.read(locationEnabledProvider.notifier).enable();
    c.read(mapVisibleProvider.notifier).set(true);
    await pumpEventQueue();
    expect(locator.controller.hasListener, isFalse);
  });
}
