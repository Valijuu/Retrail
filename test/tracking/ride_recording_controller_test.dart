import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/db/ride_dao.dart';
import 'package:retrail/data/db/trackpoint_dao.dart';
import 'package:retrail/data/repositories/ride_repository.dart';
import 'package:retrail/data/repositories/trackpoint_repository.dart';
import 'package:retrail/domain/distance_calculator.dart';
import 'package:retrail/tracking/location_fix.dart';
import 'package:retrail/tracking/location_permission.dart';
import 'package:retrail/tracking/location_source.dart';
import 'package:retrail/tracking/ride_recording_controller.dart';
import 'package:retrail/tracking/ride_tracker.dart';

/// Fake source we can pump fixes through.
class _FakeSource implements LocationSource {
  final _controller = StreamController<LocationFix>.broadcast();
  @override
  Stream<LocationFix> get fixes => _controller.stream;
  @override
  Future<LocationFix?> lastKnown() async => null;
  void emit(LocationFix f) => _controller.add(f);
  Future<void> close() => _controller.close();
}

/// Scriptable permission service.
class _FakePermissions implements LocationPermissionService {
  _FakePermissions({
    required this.serviceEnabled,
    required this.permission,
    LocationPermission? afterRequest,
  }) : afterRequest = afterRequest ?? permission;

  bool serviceEnabled;
  LocationPermission permission;
  final LocationPermission afterRequest;
  int requestCount = 0;
  int backgroundCount = 0;
  int openLocationSettingsCount = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    requestCount++;
    return permission = afterRequest;
  }

  @override
  Future<void> ensureBackgroundPermission() async => backgroundCount++;

  @override
  Future<void> openLocationSettings() async => openLocationSettingsCount++;
  @override
  Future<void> openAppSettings() async {}
}

/// Records service lifecycle calls.
class _FakeService implements RideForegroundService {
  int starts = 0;
  int stops = 0;
  bool notificationGranted = true;
  @override
  Future<void> start() async => starts++;
  @override
  Future<void> stop() async => stops++;
  @override
  Future<void> update({
    required bool isPaused,
    required int elapsedSeconds,
    required double distanceMetres,
  }) async {}
  @override
  Future<bool> ensureNotificationPermission() async => notificationGranted;
}

LocationFix _fix(double lat, double lng, int nanos) => LocationFix(
      latitude: lat,
      longitude: lng,
      accuracy: 5,
      hasSpeed: true,
      speed: 5,
      elapsedRealtimeNanos: nanos,
    );

void main() {
  late AppDatabase db;
  late RideTracker tracker;
  late _FakeSource source;
  late _FakeService service;

  setUp(() {
    db = AppDatabase.memory();
    tracker = RideTracker(
      RideRepository(RideDao(db)),
      TrackpointRepository(TrackpointDao(db)),
      const HaversineDistanceCalculator(),
      nowMs: () => 1000,
      nowNanos: () => 10000000000, // 10 s — fixes below stay fresh
    );
    source = _FakeSource();
    service = _FakeService();
  });

  tearDown(() async {
    tracker.dispose();
    await source.close();
    await db.close();
  });

  RideRecordingController controller(_FakePermissions perms) =>
      RideRecordingController(
        tracker: tracker,
        source: source,
        permissions: perms,
        service: service,
      );

  test('granted + services on: starts service + records fed fixes', () async {
    final perms = _FakePermissions(
      serviceEnabled: true,
      permission: LocationPermission.whileInUse,
    );
    final c = controller(perms);

    final action = await c.start();
    expect(action, LocationStartAction.proceed);
    expect(tracker.state.isTracking, isTrue);
    expect(service.starts, 1);
    expect(perms.backgroundCount, 1); // escalation attempted on proceed
    await pumpEventQueue(); // _beginRide insert → activeRideId

    source.emit(_fix(52.0, 13.0, 8000000000));
    source.emit(_fix(52.000108, 13.0, 9000000000)); // ~12 m / 1 s → recorded
    await pumpEventQueue();
    expect(tracker.state.trackPoints.length, 2);

    await c.stop();
    expect(service.stops, 1);
    // After stop the subscription is cancelled — late fixes are not recorded.
    source.emit(_fix(52.001, 13.0, 9500000000));
    await pumpEventQueue();
    expect(tracker.state.trackPoints.length, 2);
  });

  test('denied then granted on request → proceeds and requests once', () async {
    final perms = _FakePermissions(
      serviceEnabled: true,
      permission: LocationPermission.denied,
      afterRequest: LocationPermission.whileInUse,
    );
    final action = await controller(perms).start();
    expect(action, LocationStartAction.proceed);
    expect(perms.requestCount, 1);
    expect(tracker.state.isTracking, isTrue);
    expect(service.starts, 1);
    await pumpEventQueue(); // let _beginRide finish before teardown disposes
  });

  test('deniedForever → showRationale, nothing started', () async {
    final action = await controller(_FakePermissions(
      serviceEnabled: true,
      permission: LocationPermission.deniedForever,
    )).start();
    expect(action, LocationStartAction.showRationale);
    expect(tracker.state.isTracking, isFalse);
    expect(service.starts, 0);
  });

  test('granted but services off → openLocationSettings, nothing started',
      () async {
    final action = await controller(_FakePermissions(
      serviceEnabled: false,
      permission: LocationPermission.whileInUse,
    )).start();
    expect(action, LocationStartAction.openLocationSettings);
    expect(tracker.state.isTracking, isFalse);
    expect(service.starts, 0);
  });

  test('prepare() resolves the gate WITHOUT starting recording', () async {
    // The Start-tracking press prompts up front, before the countdown — the gate
    // runs (request once when undecided) but no source/service/ride starts yet.
    final perms = _FakePermissions(
      serviceEnabled: true,
      permission: LocationPermission.denied,
      afterRequest: LocationPermission.whileInUse,
    );
    final action = await controller(perms).prepare();
    expect(action, LocationStartAction.proceed);
    expect(perms.requestCount, 1);
    expect(tracker.state.isTracking, isFalse); // recording deferred to start()
    expect(service.starts, 0);
  });

  test('prepare() blocked → reports the action, starts nothing', () async {
    final action = await controller(_FakePermissions(
      serviceEnabled: true,
      permission: LocationPermission.deniedForever,
    )).prepare();
    expect(action, LocationStartAction.showRationale);
    expect(tracker.state.isTracking, isFalse);
    expect(service.starts, 0);
  });
}
