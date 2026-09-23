import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:retrail/data/repositories/ride_repository.dart';
import 'package:retrail/data/repositories/trackpoint_repository.dart';
import 'package:retrail/domain/activity_type.dart';
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

  setUp(() {
    rideRepo = _MockRideRepo();
    tpRepo = _MockTpRepo();
    when(() => rideRepo.startRide(
        activityTypeId: any(named: 'activityTypeId'),
        startedAtMs: any(named: 'startedAtMs'))).thenAnswer((_) async => 1);
    when(() => rideRepo.updateEndTime(any(), any())).thenAnswer((_) async {});
    when(() => rideRepo.updateRideDetails(any(), any(), any()))
        .thenAnswer((_) async {});
    when(() => rideRepo.updateFavorite(any(), any())).thenAnswer((_) async {});
    when(() => rideRepo.deleteById(any())).thenAnswer((_) async {});
    when(() => tpRepo.addTrackpoint(
        rideId: any(named: 'rideId'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
        timestampMs: any(named: 'timestampMs'),
        speedMs: any(named: 'speedMs'))).thenAnswer((_) async {});
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

  // ─── Location services (issue #33) ───────────────────────────────────────
  group('location services', () {
    test('services start as enabled', () {
      runTracker((fa, t) => expect(t.state.locationServiceEnabled, isTrue));
    });

    test('switched off mid-ride: state says so and the live speed is cleared '
        '(no frozen last value)', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        t.onLocationReceived(fix(52, 13, hasSpeed: true, speed: 3));
        expect(t.state.speedKmh, isNotNull);

        final emitted = <bool>[];
        t.changes.listen((s) => emitted.add(s.locationServiceEnabled));
        t.setLocationServiceEnabled(false);
        fa.flushMicrotasks();

        expect(t.state.locationServiceEnabled, isFalse);
        expect(t.state.speedKmh, isNull);
        expect(emitted, contains(false));
      });
    });

    test('switched back on: state recovers', () {
      runTracker((fa, t) {
        t.setLocationServiceEnabled(false);
        t.setLocationServiceEnabled(true);
        expect(t.state.locationServiceEnabled, isTrue);
      });
    });
  });

  // ─── Ride lifecycle ──────────────────────────────────────────────────────
  group('lifecycle', () {
    test('startTracking creates a ride and sets tracking', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        verify(() => rideRepo.startRide(
            activityTypeId: any(named: 'activityTypeId'),
            startedAtMs: any(named: 'startedAtMs'))).called(1);
        expect(t.state.isTracking, isTrue);
      });
    });

    test('onLocationReceived while tracking saves a trackpoint', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        final location = fix(52, 13);
        t.onLocationReceived(location);
        verify(() => tpRepo.addTrackpoint(
            rideId: any(named: 'rideId'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            timestampMs: any(named: 'timestampMs'),
            speedMs: any(named: 'speedMs'))).called(1);
        expect(t.state.location, location);
      });
    });

    test('onLocationReceived while not tracking saves nothing', () {
      runTracker((fa, t) {
        t.onLocationReceived(fix(52, 13));
        verifyNever(() => tpRepo.addTrackpoint(
            rideId: any(named: 'rideId'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            timestampMs: any(named: 'timestampMs'),
            speedMs: any(named: 'speedMs')));
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
        verifyNever(() => tpRepo.addTrackpoint(
            rideId: any(named: 'rideId'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            timestampMs: any(named: 'timestampMs'),
            speedMs: any(named: 'speedMs')));
      });
    });

    test('seedLocation centers the map from a stale fix recording would drop', () {
      // On a cold start the last-known fix is often older than the 5 s freshness
      // window, so the recording path (onLocationReceived) drops it and the map
      // is stranded at (0,0). seedLocation shows it anyway (display only) so the
      // map centres on the rider's area immediately.
      runTracker((fa, t) {
        t.nowNanos = () => 10000000000; // 10 s → a nanos:0 fix is "10 s old"
        final stale = fix(52, 13);
        t.onLocationReceived(stale);
        expect(t.state.location, isNull,
            reason: 'recording path drops the stale fix');
        t.seedLocation(stale);
        expect(t.state.location, stale);
        expect(t.state.trackPoints, isEmpty,
            reason: 'a seed is for display only — never recorded');
      });
    });

    test('seedLocation does not overwrite a fix that already arrived', () {
      runTracker((fa, t) {
        final fresh = fix(52, 13);
        t.onLocationReceived(fresh);
        t.seedLocation(fix(10, 10));
        expect(t.state.location, fresh);
      });
    });

    test('setPendingActivityType reflects in state before startTracking', () {
      // The active-ride map reads state.activityType to pick its marker. The
      // chosen activity must be visible as soon as it is set (on the Start
      // press), not only after startTracking commits it — otherwise the first
      // ride's map renders the previous activity's marker.
      runTracker((fa, t) {
        t.setPendingActivityType(ActivityType.mountainboard.id);
        expect(t.state.activityType, ActivityType.mountainboard);
      });
    });
  });

  // ─── trackPoints accumulation ────────────────────────────────────────────
  group('discardActiveRide', () {
    test('one-shot: deletes the row, never writes an endTime, fully resets',
        () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        fa.elapse(const Duration(seconds: 3));
        expect(t.state.elapsedSeconds, 3);

        t.discardActiveRide();
        expect(t.state.isTracking, isFalse); // synchronous
        expect(t.lastCompletedRideId, isNull);
        expect(t.state.elapsedSeconds, 0);
        expect(t.state.distanceMetres, 0);
        expect(t.state.trackPoints, isEmpty);
        fa.flushMicrotasks();
        verify(() => rideRepo.deleteById(1)).called(1);
        verifyNever(() => rideRepo.updateEndTime(any(), any()));
        fa.elapse(const Duration(seconds: 5));
        expect(t.state.elapsedSeconds, 0); // timer cancelled, not leaked
      });
    });

    test('latches when the begin-insert is still in flight', () {
      when(() => rideRepo.startRide(
            activityTypeId: any(named: 'activityTypeId'),
            startedAtMs: any(named: 'startedAtMs'))).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return 7;
      });
      runTracker((fa, t) {
        t.startTracking();
        t.discardActiveRide(); // ride id not known yet
        expect(t.state.isTracking, isFalse);
        fa.elapse(const Duration(milliseconds: 200));
        verify(() => rideRepo.deleteById(7)).called(1);
        verifyNever(() => rideRepo.updateEndTime(any(), any()));
      });
    });
  });

  // Back → discard immediately after starting can stop/discard while
  // _beginRide's insert is still in flight. The tracker must not end up
  // half-tracking (leaked elapsed timer, isTracking stuck true) or orphan the
  // ride row — that broken state compounded on repeats and crashed the app.
  group('stop/discard racing the begin insert', () {
    test('stop while the insert is in flight flips state immediately and '
        'finalizes the ride once inserted (no leaked timer)', () {
      when(() => rideRepo.startRide(
            activityTypeId: any(named: 'activityTypeId'),
            startedAtMs: any(named: 'startedAtMs'))).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return 7;
      });
      runTracker((fa, t) {
        t.startTracking();
        t.stopTracking(); // insert not landed yet
        expect(t.state.isTracking, isFalse); // stop always takes effect
        fa.elapse(const Duration(milliseconds: 200));
        expect(t.lastCompletedRideId, 7); // late insert → completed, not live
        verify(() => rideRepo.updateEndTime(7, any())).called(1);
        fa.elapse(const Duration(seconds: 5));
        expect(t.state.elapsedSeconds, 0); // elapsed timer never leaked
        expect(t.state.isTracking, isFalse);
      });
    });

    test('discard while the insert is in flight deletes the row when it lands',
        () {
      when(() => rideRepo.startRide(
            activityTypeId: any(named: 'activityTypeId'),
            startedAtMs: any(named: 'startedAtMs'))).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return 7;
      });
      runTracker((fa, t) {
        t.startTracking();
        t.stopTracking();
        t.discardRide(); // completed ride id not known yet — must latch
        fa.elapse(const Duration(milliseconds: 200));
        verify(() => rideRepo.deleteById(7)).called(1);
        verifyNever(() => rideRepo.updateEndTime(any(), any()));
        expect(t.lastCompletedRideId, isNull);
      });
    });

    test('discarding the previous ride does not clobber a NEW active ride',
        () {
      var nextId = 0;
      when(() => rideRepo.startRide(
            activityTypeId: any(named: 'activityTypeId'),
            startedAtMs: any(named: 'startedAtMs'))).thenAnswer((_) async => ++nextId);
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        t.stopTracking(); // ride 1 completed, awaiting save/discard
        t.startTracking(); // new ride begins before the deferred discard runs
        fa.flushMicrotasks();
        fa.elapse(const Duration(seconds: 3));
        expect(t.state.elapsedSeconds, 3);

        t.discardRide(); // deletes ride 1 only
        expect(t.state.isTracking, isTrue);
        expect(t.state.elapsedSeconds, 3); // live state untouched
        verify(() => rideRepo.deleteById(1)).called(1);
      });
    });
  });

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
        verifyNever(() => tpRepo.addTrackpoint(
            rideId: any(named: 'rideId'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            timestampMs: any(named: 'timestampMs'),
            speedMs: any(named: 'speedMs')));
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
        verifyNever(() => tpRepo.addTrackpoint(
            rideId: any(named: 'rideId'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            timestampMs: any(named: 'timestampMs'),
            speedMs: any(named: 'speedMs')));
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

    test('near-zero provider speed is not recorded after the first point', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        t.onLocationReceived(fix(52, 13, nanos: 0)); // first point recorded
        // A later stationary fix is dropped by the stationary guard.
        t.onLocationReceived(fix(52.001, 13.001,
            hasSpeed: true, speed: 0.5, nanos: 2000000000)); // < 0.8
        expect(t.state.trackPoints, hasLength(1));
      });
    });

    test('first fix is recorded even standing still (no-move ride has a point)',
        () {
      // The start location must always be captured so a ride begun (and ended)
      // at rest still has a point — a dot in the preview, not "No route".
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        t.onLocationReceived(fix(52, 13, hasSpeed: true, speed: 0.0)); // at rest
        expect(t.state.trackPoints, hasLength(1));
        verify(() => tpRepo.addTrackpoint(
            rideId: any(named: 'rideId'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            timestampMs: any(named: 'timestampMs'),
            speedMs: any(named: 'speedMs'))).called(1);
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

  // ─── Persistence seam (issue #3) ─────────────────────────────────────────
  //
  // The tracker used to build Drift `RidesCompanion`/`TrackpointsCompanion`
  // objects itself, so a test could only assert `insert(any())` — the actual
  // values were sealed inside an opaque Drift type. With intent-revealing
  // repository methods the recorded values are assertable.
  group('persistence seam', () {
    test('starts the ride with its activity type and start time', () {
      runTracker((fa, t) {
        t.nowMs = () => 777000;
        t.setPendingActivityType('SKATEBOARD');
        t.startTracking();
        fa.flushMicrotasks();
        verify(() => rideRepo.startRide(
            activityTypeId: 'SKATEBOARD', startedAtMs: 777000)).called(1);
      });
    });

    test('records a trackpoint with the fix coordinates and speed', () {
      runTracker((fa, t) {
        t.nowMs = () => 999000;
        t.startTracking();
        fa.flushMicrotasks();
        t.onLocationReceived(fix(52.5, 13.4, hasSpeed: true, speed: 4.2));
        verify(() => tpRepo.addTrackpoint(
              rideId: 1,
              latitude: 52.5,
              longitude: 13.4,
              timestampMs: 999000,
              speedMs: 4.2,
            )).called(1);
      });
    });

    test('records a null speed when the fix carries none', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        t.onLocationReceived(fix(52.5, 13.4)); // hasSpeed: false
        verify(() => tpRepo.addTrackpoint(
              rideId: any(named: 'rideId'),
              latitude: any(named: 'latitude'),
              longitude: any(named: 'longitude'),
              timestampMs: any(named: 'timestampMs'),
              speedMs: null,
            )).called(1);
      });
    });
  });

  test('dispose during an in-flight begin does not emit on a closed stream',
      () {
    // App shutdown / provider-container teardown right after the ride starts:
    // startTracking() leaves the ride-insert in flight, and its continuation
    // used to call _emit() on the already-closed controller ("Bad state:
    // Cannot add new events after calling close").
    fakeAsync((fa) {
      final t = RideTracker(rideRepo, tpRepo, const _FixedCalc(100));
      t.nowNanos = () => 0;
      t.startTracking(); // insert in flight
      t.dispose(); // container torn down before it lands
      expect(() => fa.flushMicrotasks(), returnsNormally);
    });
  });

  // ─── Max speed (issue #1) ────────────────────────────────────────────────
  //
  // Max speed used to be accumulated in the active-ride screen's widget State,
  // so it reset to 0 whenever the screen was disposed and recreated mid-ride
  // (backgrounding + notification tap, deep-link reopen, navigation replace).
  // It belongs to the process-lifetime tracker, which outlives the screen.
  group('max speed', () {
    test('grows with the fastest fix seen while tracking', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        t.onLocationReceived(fix(52, 13, hasSpeed: true, speed: 5.0)); // 18 km/h
        expect(t.state.maxSpeedKmh, closeTo(18.0, 0.001));
      });
    });

    test('never shrinks when a slower fix arrives', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        t.onLocationReceived(fix(52, 13, hasSpeed: true, speed: 10.0)); // 36 km/h
        t.onLocationReceived(fix(52, 13, hasSpeed: true, speed: 2.0)); // 7.2 km/h
        expect(t.state.maxSpeedKmh, closeTo(36.0, 0.001));
      });
    });

    test('survives across many fixes — the tracker outlives the screen', () {
      // The regression this guards: the value lives in the tracker, so a
      // screen teardown/rebuild mid-ride cannot reset it.
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        t.onLocationReceived(fix(52, 13, hasSpeed: true, speed: 12.0)); // 43.2
        for (var i = 0; i < 5; i++) {
          t.onLocationReceived(fix(52, 13, hasSpeed: true, speed: 1.0));
        }
        expect(t.state.maxSpeedKmh, closeTo(43.2, 0.001));
      });
    });

    test('is frozen while paused', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        t.onLocationReceived(fix(52, 13, hasSpeed: true, speed: 5.0)); // 18 km/h
        t.pause();
        t.onLocationReceived(fix(52, 13, hasSpeed: true, speed: 20.0)); // 72 km/h
        expect(t.state.maxSpeedKmh, closeTo(18.0, 0.001));
      });
    });

    test('resets to 0 when the ride stops', () {
      runTracker((fa, t) {
        t.startTracking();
        fa.flushMicrotasks();
        t.onLocationReceived(fix(52, 13, hasSpeed: true, speed: 5.0));
        t.stopTracking();
        expect(t.state.maxSpeedKmh, 0.0);
      });
    });
  });
}
