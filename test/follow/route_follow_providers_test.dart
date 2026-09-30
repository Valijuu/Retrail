// test/follow/route_follow_providers_test.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/features/follow/route_follow_providers.dart';
import 'package:retrail/tracking/location_fix.dart';
import 'package:retrail/tracking/location_source.dart';
import 'package:retrail/tracking/ride_tracking_state.dart';
import 'package:retrail/tracking/tracking_providers.dart';

class FakeLocationSource implements LocationSource {
  final fixCtrl = StreamController<LocationFix>.broadcast();
  final serviceCtrl = StreamController<bool>.broadcast();
  LocationFix? last;
  @override
  Stream<LocationFix> get fixes => fixCtrl.stream;
  @override
  Stream<bool> get serviceEnabled => serviceCtrl.stream;
  @override
  Future<LocationFix?> lastKnown() async => last;
}

LocationFix fix(double lat, double lng, {double accuracy = 5}) => LocationFix(
  latitude: lat,
  longitude: lng,
  accuracy: accuracy,
  hasSpeed: false,
  speed: 0,
  elapsedRealtimeNanos: 0,
);

// ~111 m per 0.001° latitude.
const _ref = [
  (lat: 48.0, lng: 11.0),
  (lat: 48.001, lng: 11.0),
  (lat: 48.002, lng: 11.0),
];

void main() {
  late FakeLocationSource source;
  late StreamController<RideTrackingState> tracker;
  late ProviderContainer c;

  setUp(() {
    source = FakeLocationSource();
    tracker = StreamController<RideTrackingState>.broadcast();
    c = ProviderContainer(
      overrides: [
        locationSourceProvider.overrideWithValue(source),
        rideTrackingStateProvider.overrideWith((ref) => tracker.stream),
      ],
    );
    c.listen(routeFollowProvider, (_, _) {});
  });
  tearDown(() => c.dispose());

  Future<void> flush() => Future<void>.delayed(Duration.zero);
  RouteFollowNotifier notifier() => c.read(routeFollowProvider.notifier);

  test('starts without a reference', () {
    expect(c.read(routeFollowProvider), isNull);
  });

  test('start sets reference, title and mode; stop clears it', () {
    notifier().start(reference: _ref, rideTitle: 'Rhein', recording: false);
    final s = c.read(routeFollowProvider)!;
    expect(s.track.points, _ref);
    expect(s.rideTitle, 'Rhein');
    expect(s.recording, isFalse);
    expect(s.progress, isNull);
    notifier().stop();
    expect(c.read(routeFollowProvider), isNull);
  });

  test('follow-only: feed fixes update progress, position and trail', () async {
    notifier().start(reference: _ref, recording: false);
    await notifier().resumeFeed();
    source.fixCtrl.add(fix(48.001, 11.0));
    await flush();
    final s = c.read(routeFollowProvider)!;
    expect(s.progress!.alongM, closeTo(111.2, 1));
    expect(s.lastFix!.latitude, 48.001);
    expect(s.trail, [(lat: 48.001, lng: 11.0)]);
  });

  test('follow-only: the last known fix seeds the position', () async {
    source.last = fix(48.0005, 11.0);
    notifier().start(reference: _ref, recording: false);
    await notifier().resumeFeed();
    expect(c.read(routeFollowProvider)!.progress!.alongM, closeTo(55.6, 1));
  });

  test('inaccurate fixes are ignored', () async {
    notifier().start(reference: _ref, recording: false);
    await notifier().resumeFeed();
    source.fixCtrl.add(fix(48.001, 11.0, accuracy: 80));
    await flush();
    expect(c.read(routeFollowProvider)!.lastFix, isNull);
  });

  test('location services off/on is reflected', () async {
    notifier().start(reference: _ref, recording: false);
    await notifier().resumeFeed();
    source.serviceCtrl.add(false);
    await flush();
    expect(c.read(routeFollowProvider)!.locationServiceEnabled, isFalse);
    source.serviceCtrl.add(true);
    await flush();
    expect(c.read(routeFollowProvider)!.locationServiceEnabled, isTrue);
  });

  test('pauseFeed stops listening until resumed', () async {
    notifier().start(reference: _ref, recording: false);
    await notifier().resumeFeed();
    notifier().pauseFeed();
    source.fixCtrl.add(fix(48.001, 11.0));
    await flush();
    expect(c.read(routeFollowProvider)!.lastFix, isNull);
    await notifier().resumeFeed();
    source.fixCtrl.add(fix(48.001, 11.0));
    await flush();
    expect(c.read(routeFollowProvider)!.lastFix, isNotNull);
  });

  test('a stop during resumeFeed does not leave a subscription', () async {
    notifier().start(reference: _ref, recording: false);
    final pending = notifier().resumeFeed();
    notifier().stop();
    await pending;
    expect(source.fixCtrl.hasListener, isFalse);
  });

  test('recording: the recorder position drives progress', () async {
    notifier().start(reference: _ref, recording: true);
    tracker.add(
      RideTrackingState(isTracking: true, location: fix(48.001, 11.0)),
    );
    await flush();
    expect(c.read(routeFollowProvider)!.progress!.alongM, closeTo(111.2, 1));
  });

  test('recording mode never opens its own GPS feed', () async {
    notifier().start(reference: _ref, recording: true);
    await notifier().resumeFeed();
    expect(source.fixCtrl.hasListener, isFalse);
  });

  test('follow-only ignores the recorder position', () async {
    notifier().start(reference: _ref, recording: false);
    tracker.add(
      RideTrackingState(isTracking: true, location: fix(48.001, 11.0)),
    );
    await flush();
    expect(c.read(routeFollowProvider)!.lastFix, isNull);
  });
}
