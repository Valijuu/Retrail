import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/repositories/ride_repository.dart';
import 'package:retrail/data/repositories/trackpoint_repository.dart';
import 'package:retrail/domain/distance_calculator.dart';
import 'package:retrail/tracking/location_fix.dart';
import 'package:retrail/tracking/ride_tracker.dart';

class _MockRideRepo extends Mock implements RideRepository {}

class _MockTpRepo extends Mock implements TrackpointRepository {}

/// Fixed distance per segment, isolating the filter from geometry (matches the
/// original test's mocked DistanceCalculator returning 100).
class _FixedCalc implements DistanceCalculator {
  const _FixedCalc(this.metres);
  final double metres;
  @override
  double distanceBetween(double a, double b, double c, double d) => metres;
}

LocationFix fix(
  double lat,
  double lng, {
  double accuracy = 5,
  bool hasSpeed = false,
  double speed = 0,
  int nanos = 0,
}) =>
    LocationFix(
      latitude: lat,
      longitude: lng,
      accuracy: accuracy,
      hasSpeed: hasSpeed,
      speed: speed,
      elapsedRealtimeNanos: nanos,
    );

void main() {
  late _MockRideRepo rideRepo;
  late _MockTpRepo tpRepo;

  setUpAll(() {
    registerFallbackValue(const RidesCompanion());
    registerFallbackValue(const TrackpointsCompanion());
  });

  setUp(() {
    rideRepo = _MockRideRepo();
    tpRepo = _MockTpRepo();
    when(() => rideRepo.insert(any())).thenAnswer((_) async => 1);
    when(() => rideRepo.updateEndTime(any(), any())).thenAnswer((_) async {});
    when(() => rideRepo.updateRideDetails(any(), any(), any()))
        .thenAnswer((_) async {});
    when(() => rideRepo.updateFavorite(any(), any())).thenAnswer((_) async {});
    when(() => rideRepo.deleteById(any())).thenAnswer((_) async {});
    when(() => tpRepo.insert(any())).thenAnswer((_) async => 1);
  });

  /// Runs [body] inside virtual time with a freshly-built tracker (nowNanos = 0).
  void runTracker(void Function(FakeAsync fa, RideTracker t) body) {
    fakeAsync((fa) {
      final t = RideTracker(
        rideRepo,
        tpRepo,
        const _FixedCalc(100),
      );
      t.nowNanos = () => 0;
      body(fa, t);
      t.dispose();
    });
  }

  // ─── Ride lifecycle ──────────────────────────────────────────────────────
  group('lifecycle', () {
    test('startTracking creates a ride and sets tracking', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        verify(() => rideRepo.insert(any())).called(1);
        expect(t.state.isTracking, isTrue);
      });
    });

    test('onLocationReceived while tracking saves a trackpoint', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        final location = fix(52, 13);
        t.onLocationReceived(location);
        verify(() => tpRepo.insert(any())).called(1);
        expect(t.state.location, location);
      });
    });

    test('onLocationReceived while not tracking saves nothing', () {
      runTracker((fa, t) {
        t.onLocationReceived(fix(52, 13));
        verifyNever(() => tpRepo.insert(any()));
      });
    });

    test('stopTracking updates endTime and clears tracking', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        t.stopTracking();
        fa.flushMicrotasks();
        verify(() => rideRepo.updateEndTime(1, any())).called(1);
        expect(t.state.isTracking, isFalse);
      });
    });

    test('high-inaccuracy fix is discarded', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        t.onLocationReceived(fix(52, 13, accuracy: 80));
        expect(t.state.trackPoints, isEmpty);
        verifyNever(() => tpRepo.insert(any()));
      });
    });
  });

  // ─── trackPoints accumulation ────────────────────────────────────────────
  group('trackPoints', () {
    test('initially empty', () {
      runTracker((fa, t) => expect(t.state.trackPoints, isEmpty));
    });

    test('appends one point', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        t.onLocationReceived(fix(52, 13));
        expect(t.state.trackPoints, hasLength(1));
      });
    });

    test('appends multiple points', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        t.onLocationReceived(fix(52.0, 13.0));
        t.onLocationReceived(fix(52.1, 13.1));
        t.onLocationReceived(fix(52.2, 13.2));
        expect(t.state.trackPoints, hasLength(3));
      });
    });

    test('second startTracking resets trackPoints', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        t.onLocationReceived(fix(52, 13));
        t.onLocationReceived(fix(52.1, 13.1));
        t.startTracking();
        fa.flushMicrotasks();
        expect(t.state.trackPoints, isEmpty);
      });
    });
  });

  // ─── distance ────────────────────────────────────────────────────────────
  group('distance', () {
    test('initially zero', () {
      runTracker((fa, t) => expect(t.state.distanceMetres, 0));
    });

    test('first point keeps distance zero', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        t.onLocationReceived(fix(52, 13));
        expect(t.state.distanceMetres, 0);
      });
    });

    test('second point increases distance', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        t.onLocationReceived(fix(52.0, 13.0));
        t.onLocationReceived(fix(52.1, 13.1));
        expect(t.state.distanceMetres, 100);
      });
    });

    test('second startTracking resets distance', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        t.onLocationReceived(fix(52.0, 13.0));
        t.onLocationReceived(fix(52.1, 13.1));
        t.startTracking();
        fa.flushMicrotasks();
        expect(t.state.distanceMetres, 0);
      });
    });
  });

  // ─── speed ───────────────────────────────────────────────────────────────
  group('speed', () {
    test('initially null', () {
      runTracker((fa, t) => expect(t.state.speedKmh, isNull));
    });

    test('uses provider speed when present', () {
      runTracker((fa, t) {
        t.onLocationReceived(fix(52, 13, hasSpeed: true, speed: 10));
        expect(t.state.speedKmh, closeTo(36, 1e-9));
      });
    });

    test('first fix without speed is null', () {
      runTracker((fa, t) {
        t.onLocationReceived(fix(52, 13));
        expect(t.state.speedKmh, isNull);
      });
    });

    test('falls back to computed speed when provider omits it', () {
      runTracker((fa, t) {
        t.onLocationReceived(fix(52.0, 13.0, nanos: 0));
        t.onLocationReceived(fix(52.1, 13.1, nanos: 1000000000)); // +1s, 100 m
        expect(t.state.speedKmh, closeTo(360, 1e-6)); // 100 m/s × 3.6
      });
    });

    test('speed updates even when not tracking', () {
      runTracker((fa, t) {
        t.onLocationReceived(fix(52, 13, hasSpeed: true, speed: 5));
        expect(t.state.speedKmh, closeTo(18, 1e-9));
      });
    });

    test('stopTracking does not reset speed', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        t.onLocationReceived(fix(52, 13, hasSpeed: true, speed: 10));
        t.stopTracking();
        fa.flushMicrotasks();
        expect(t.state.speedKmh, closeTo(36, 1e-9));
      });
    });
  });

  // ─── elapsed timer ───────────────────────────────────────────────────────
  group('elapsed', () {
    test('initially zero', () {
      runTracker((fa, t) => expect(t.state.elapsedSeconds, 0));
    });

    test('startTracking starts the elapsed timer', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        fa.elapse(const Duration(seconds: 3));
        expect(t.state.elapsedSeconds, 3);
      });
    });

    test('stopTracking stops the elapsed timer', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        fa.elapse(const Duration(seconds: 2));
        t.stopTracking();
        fa.flushMicrotasks();
        fa.elapse(const Duration(seconds: 5));
        expect(t.state.elapsedSeconds, 2);
      });
    });

    test('second startTracking resets elapsed seconds', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        fa.elapse(const Duration(seconds: 3));
        t.startTracking();
        fa.flushMicrotasks();
        expect(t.state.elapsedSeconds, 0);
      });
    });
  });

  // ─── pause / resume ──────────────────────────────────────────────────────
  group('pause/resume', () {
    test('isPaused initially false', () {
      runTracker((fa, t) => expect(t.state.isPaused, isFalse));
    });

    test('pause sets isPaused', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        t.pause();
        expect(t.state.isPaused, isTrue);
      });
    });

    test('resume clears isPaused', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        t.pause();
        t.resume();
        expect(t.state.isPaused, isFalse);
      });
    });

    test('pause when not tracking is a no-op', () {
      runTracker((fa, t) {
        t.pause();
        expect(t.state.isPaused, isFalse);
      });
    });

    test('paused fix does not save a trackpoint', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        t.pause();
        t.onLocationReceived(fix(52, 13));
        verifyNever(() => tpRepo.insert(any()));
      });
    });

    test('paused fix still updates the live location', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        t.pause();
        final location = fix(52, 13);
        t.onLocationReceived(location);
        expect(t.state.location, location);
      });
    });

    test('pause freezes the elapsed timer', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        fa.elapse(const Duration(seconds: 2));
        t.pause();
        fa.elapse(const Duration(seconds: 5));
        expect(t.state.elapsedSeconds, 2);
      });
    });

    test('resume continues the timer from the frozen value', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        fa.elapse(const Duration(seconds: 2));
        t.pause();
        fa.elapse(const Duration(seconds: 5));
        t.resume();
        fa.elapse(const Duration(seconds: 3));
        expect(t.state.elapsedSeconds, 5);
      });
    });

    test('pause does not accumulate distance', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        t.onLocationReceived(fix(52.0, 13.0));
        t.onLocationReceived(fix(52.1, 13.1)); // distance 100
        t.pause();
        t.onLocationReceived(fix(52.2, 13.2)); // ignored
        expect(t.state.distanceMetres, 100);
      });
    });

    test('resume does not count the break gap as distance', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        t.onLocationReceived(fix(52.0, 13.0));
        t.onLocationReceived(fix(52.1, 13.1)); // distance 100
        t.pause();
        t.onLocationReceived(fix(52.5, 13.5)); // ignored while paused
        t.resume();
        t.onLocationReceived(fix(52.6, 13.6)); // first point after resume
        expect(t.state.distanceMetres, 100);
      });
    });
  });

  // ─── freshness / outlier / drift filters ─────────────────────────────────
  group('filters', () {
    test('stale fix is rejected entirely', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        t.nowNanos = () => 10000000000; // 10 s
        t.onLocationReceived(fix(52, 13, nanos: 0)); // age 10 s > 5 s
        expect(t.state.location, isNull);
        expect(t.state.trackPoints, isEmpty);
        verifyNever(() => tpRepo.insert(any()));
      });
    });

    test('stale first fix: route starts from the fresh fix, distance not inflated',
        () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        t.nowNanos = () => 10000000000;
        t.onLocationReceived(fix(40, 10, nanos: 0)); // stale → rejected
        t.onLocationReceived(fix(52, 13, nanos: 10000000000)); // fresh
        expect(t.state.trackPoints, hasLength(1));
        expect(t.state.distanceMetres, 0);
      });
    });

    test('fresh fix is recorded', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        t.onLocationReceived(fix(52, 13, nanos: 0)); // age 0
        expect(t.state.trackPoints, hasLength(1));
      });
    });

    test('mid-ride teleport is dropped, good points survive', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        t.onLocationReceived(fix(52.0, 13.0, nanos: 0)); // point 1
        t.onLocationReceived(fix(52.1, 13.1, nanos: 1000000000)); // 100 m/1 s = 100 m/s → drop
        t.onLocationReceived(fix(52.2, 13.2, nanos: 3000000000)); // 100 m/3 s ≈ 33 m/s → keep
        expect(t.state.trackPoints, hasLength(2));
      });
    });

    test('near-zero provider speed is not recorded', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        t.onLocationReceived(fix(52, 13, hasSpeed: true, speed: 0.5)); // < 0.8
        expect(t.state.trackPoints, isEmpty);
        verifyNever(() => tpRepo.insert(any()));
      });
    });

    test('real provider speed is recorded', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        t.onLocationReceived(fix(52, 13, hasSpeed: true, speed: 2.0)); // > 0.8
        expect(t.state.trackPoints, hasLength(1));
      });
    });
  });
}
