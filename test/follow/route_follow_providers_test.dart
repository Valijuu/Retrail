import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/features/follow/route_follow_providers.dart';
import 'package:retrail/tracking/location_fix.dart';
import 'package:retrail/tracking/location_source.dart';
import 'package:retrail/tracking/ride_recording_controller.dart';
import 'package:retrail/tracking/ride_tracking_state.dart';
import 'package:retrail/tracking/tracking_providers.dart';

class FakePermissions implements LocationPermissionService {
  bool serviceEnabled = true;
  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLocationSource implements LocationSource {
  bool lastKnownThrows = false;
  final fixCtrl = StreamController<LocationFix>.broadcast();
  final serviceCtrl = StreamController<bool>.broadcast();
  LocationFix? last;
  @override
  Stream<LocationFix> get fixes => fixCtrl.stream;
  @override
  Stream<bool> get serviceEnabled => serviceCtrl.stream;
  @override
  Future<LocationFix?> lastKnown() async {
    if (lastKnownThrows) throw StateError('no last known');
    return last;
  }
}

LocationFix fix(double lat, double lng, {double accuracy = 5, int atNanos = 0}) =>
    LocationFix(
  latitude: lat,
  longitude: lng,
  accuracy: accuracy,
  hasSpeed: false,
  speed: 0,
  elapsedRealtimeNanos: atNanos,
);

int _nanos(Duration d) => d.inMicroseconds * 1000;

// ~111 m per 0.001° latitude.
const _ref = [
  (lat: 48.0, lng: 11.0),
  (lat: 48.001, lng: 11.0),
  (lat: 48.002, lng: 11.0),
];

void main() {
  late FakeLocationSource source;
  late FakePermissions permissions;
  late StreamController<RideTrackingState> tracker;
  late ProviderContainer c;
  // The follow clock; fixes default to capture time 0, i.e. fresh.
  var nowNanos = 0;

  setUp(() {
    nowNanos = 0;
    source = FakeLocationSource();
    permissions = FakePermissions();
    tracker = StreamController<RideTrackingState>.broadcast();
    c = ProviderContainer(
      overrides: [
        locationSourceProvider.overrideWithValue(source),
        locationPermissionServiceProvider.overrideWithValue(permissions),
        rideTrackingStateProvider.overrideWith((ref) => tracker.stream),
        followNowNanosProvider.overrideWithValue(() => nowNanos),
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

  test('a pause during resumeFeed does not leave a subscription', () async {
    notifier().start(reference: _ref, recording: false);
    final pending = notifier().resumeFeed();
    notifier().pauseFeed();
    await pending;
    expect(source.fixCtrl.hasListener, isFalse);
    expect(source.serviceCtrl.hasListener, isFalse);
  });

  test('recording: an unchanged recorder location is not re-applied', () async {
    notifier().start(reference: _ref, recording: true);
    final loc = fix(48.001, 11.0);
    tracker.add(RideTrackingState(isTracking: true, location: loc));
    await flush();
    tracker.add(RideTrackingState(isTracking: true, location: loc));
    await flush();
    expect(c.read(routeFollowProvider)!.trail.length, 1);
  });

  test('resumeFeed seeds the location-services flag', () async {
    permissions.serviceEnabled = false;
    notifier().start(reference: _ref, recording: false);
    await notifier().resumeFeed();
    expect(c.read(routeFollowProvider)!.locationServiceEnabled, isFalse);
  });

  test('a failing lastKnown still starts the feed', () async {
    source.lastKnownThrows = true;
    notifier().start(reference: _ref, recording: false);
    await notifier().resumeFeed();
    source.fixCtrl.add(fix(48.001, 11.0));
    await flush();
    expect(c.read(routeFollowProvider)!.lastFix, isNotNull);
  });

  test('recording: a recorder location while not tracking is ignored',
      () async {
    notifier().start(reference: _ref, recording: true);
    tracker.add(
      RideTrackingState(isTracking: false, location: fix(48.001, 11.0)),
    );
    await flush();
    expect(c.read(routeFollowProvider)!.lastFix, isNull);
  });

  test('follow-only: a last known fix older than 2 minutes is ignored',
      () async {
    source.last = fix(48.0005, 11.0);
    nowNanos = _nanos(const Duration(minutes: 2, seconds: 1));
    notifier().start(reference: _ref, recording: false);
    await notifier().resumeFeed();
    expect(c.read(routeFollowProvider)!.lastFix, isNull);
  });

  test('follow-only: a last known fix within 2 minutes seeds the position',
      () async {
    source.last = fix(48.0005, 11.0, atNanos: _nanos(const Duration(minutes: 5)));
    nowNanos = _nanos(const Duration(minutes: 6, seconds: 30));
    notifier().start(reference: _ref, recording: false);
    await notifier().resumeFeed();
    expect(c.read(routeFollowProvider)!.lastFix, isNotNull);
  });

  test('follow-only: a feed error shows location as off until the next fix',
      () async {
    notifier().start(reference: _ref, recording: false);
    await notifier().resumeFeed();
    source.fixCtrl.addError(StateError('gps lost'));
    await flush();
    expect(c.read(routeFollowProvider)!.locationServiceEnabled, isFalse);
    source.fixCtrl.add(fix(48.001, 11.0));
    await flush();
    expect(c.read(routeFollowProvider)!.locationServiceEnabled, isTrue);
  });

  test('follow-only: a seed fix does not override location services off',
      () async {
    permissions.serviceEnabled = false;
    source.last = fix(48.0005, 11.0);
    notifier().start(reference: _ref, recording: false);
    await notifier().resumeFeed();
    expect(c.read(routeFollowProvider)!.locationServiceEnabled, isFalse);
  });
}
