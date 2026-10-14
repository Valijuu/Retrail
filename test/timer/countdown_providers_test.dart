import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/features/timer/countdown_providers.dart';
import 'package:retrail/tracking/gps_signal.dart';
import 'package:retrail/tracking/location_fix.dart';
import 'package:retrail/tracking/ride_tracking_state.dart';
import 'package:retrail/tracking/tracking_providers.dart';

const _start = 100 * 1000000000; // 100 s

LocationFix _fix(int atNanos, {double accuracy = 5}) => LocationFix(
      latitude: 50.0,
      longitude: 8.0,
      accuracy: accuracy,
      hasSpeed: false,
      speed: 0,
      elapsedRealtimeNanos: atNanos,
    );

void main() {
  late StreamController<RideTrackingState> states;
  late int now;

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      rideTrackingStateProvider.overrideWith((ref) => states.stream),
      gpsNowNanosProvider.overrideWithValue(() => now),
    ]);
    addTearDown(c.dispose);
    // Keep the auto-dispose provider alive like the countdown does.
    c.listen(countdownGpsSignalProvider, (_, _) {});
    return c;
  }

  setUp(() {
    states = StreamController<RideTrackingState>();
    now = _start;
  });

  test('before any tracking state: searching', () {
    expect(container().read(countdownGpsSignalProvider), GpsSignal.searching);
  });

  test('a fresh, accurate fix: ready', () async {
    final c = container();
    states.add(RideTrackingState(location: _fix(_start)));
    await Future<void>.delayed(Duration.zero);
    expect(c.read(countdownGpsSignalProvider), GpsSignal.ready);
  });

  test('location services off: off', () async {
    final c = container();
    states.add(const RideTrackingState(locationServiceEnabled: false));
    await Future<void>.delayed(Duration.zero);
    expect(c.read(countdownGpsSignalProvider), GpsSignal.off);
  });

  test('no newer fix arrives: back to searching once the fix is stale',
      () {
    fakeAsync((fa) {
      final c = container();
      states.add(RideTrackingState(location: _fix(_start)));
      fa.flushMicrotasks();
      expect(c.read(countdownGpsSignalProvider), GpsSignal.ready);

      void advance(Duration d) {
        now += d.inMicroseconds * 1000;
        fa.elapse(d);
      }

      advance(const Duration(seconds: 5));
      expect(c.read(countdownGpsSignalProvider), GpsSignal.ready);
      advance(const Duration(milliseconds: 1));
      expect(c.read(countdownGpsSignalProvider), GpsSignal.searching);
    });
  });

  test('an inaccurate fix: searching', () async {
    final c = container();
    states.add(RideTrackingState(location: _fix(_start, accuracy: 60)));
    await Future<void>.delayed(Duration.zero);
    expect(c.read(countdownGpsSignalProvider), GpsSignal.searching);
  });

  test('a newer fix keeps it ready past the first fix\'s expiry', () {
    fakeAsync((fa) {
      final c = container();
      void advance(Duration d) {
        now += d.inMicroseconds * 1000;
        fa.elapse(d);
      }

      states.add(RideTrackingState(location: _fix(_start)));
      fa.flushMicrotasks();
      advance(const Duration(seconds: 3));
      states.add(RideTrackingState(location: _fix(now)));
      fa.flushMicrotasks();
      advance(const Duration(milliseconds: 2001));
      expect(c.read(countdownGpsSignalProvider), GpsSignal.ready);
    });
  });

  test('leaves no timer behind once disposed', () {
    fakeAsync((fa) {
      final c = container();
      states.add(RideTrackingState(location: _fix(_start)));
      fa.flushMicrotasks();
      expect(fa.pendingTimers, isNotEmpty);
      c.dispose();
      expect(fa.pendingTimers, isEmpty);
    });
  });
}
