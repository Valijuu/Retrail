import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/db/ride_dao.dart';
import 'package:retrail/data/db/trackpoint_dao.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/data/repositories/ride_repository.dart';
import 'package:retrail/data/repositories/trackpoint_repository.dart';
import 'package:retrail/features/settings/settings_providers.dart';
import 'package:retrail/tracking/foreground_task_service.dart';
import 'package:retrail/tracking/live_activity_service.dart';
import 'package:retrail/tracking/location_fix.dart';
import 'package:retrail/tracking/location_source.dart';
import 'package:retrail/tracking/ride_recording_controller.dart';
import 'package:retrail/tracking/tracking_providers.dart';

/// Fake source whose listener count is observable — that is what tells us
/// whether the controller's GPS subscription was actually cancelled.
class _FakeSource implements LocationSource {
  @override
  Stream<bool> get serviceEnabled => const Stream.empty();
  final _controller = StreamController<LocationFix>.broadcast();

  @override
  Stream<LocationFix> get fixes => _controller.stream;
  @override
  Future<LocationFix?> lastKnown() async => null;

  bool get hasListener => _controller.hasListener;
  Future<void> close() => _controller.close();
}

class _GrantedPerms implements LocationPermissionService {
  @override
  Future<bool> isPreciseLocation() async => true;
  @override
  Future<void> requestPreciseLocation() async {}
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<void> ensureBackgroundPermission() async {}
  @override
  Future<void> openLocationSettings() async {}
  @override
  Future<void> openAppSettings() async {}
}

class _NoopService implements RideForegroundService {
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> update({
    required bool isPaused,
    required int elapsedSeconds,
    required double distanceMetres,
  }) async {}
  @override
  Future<bool> ensureNotificationPermission() async => true;
}

void main() {
  late AppDatabase db;
  late _FakeSource source;

  setUp(() {
    db = AppDatabase.memory();
    source = _FakeSource();
  });

  tearDown(() async {
    await source.close();
    await db.close();
  });

  ProviderContainer makeContainer() => ProviderContainer(overrides: [
        rideRepositoryProvider.overrideWithValue(RideRepository(RideDao(db))),
        trackpointRepositoryProvider
            .overrideWithValue(TrackpointRepository(TrackpointDao(db))),
        locationSourceProvider.overrideWithValue(source),
        locationPermissionServiceProvider.overrideWithValue(_GrantedPerms()),
        rideForegroundServiceProvider.overrideWithValue(_NoopService()),
      ]);

  test(
      'disposing the container mid-ride cancels the GPS subscription '
      '(issue #2: leaked when stop() never ran)', () async {
    // App shutdown mid-ride, a torn-down provider scope, or a fresh container
    // in a test: stop() never runs, so cleanup has to come from the provider.
    final container = makeContainer();
    await container.read(rideRecordingControllerProvider).start();
    expect(source.hasListener, isTrue, reason: 'recording should be streaming');

    container.dispose();
    await Future<void>.delayed(Duration.zero); // let the cancel land

    expect(source.hasListener, isFalse,
        reason: 'the fix subscription must not outlive the provider container');
  });

  test(
      'rideNotificationCopyProvider follows the device locale when the app '
      'language is "system" (issue: always fell back to English there, '
      'since localeProvider is null for "system" and the ternary treated '
      'that as "not German" instead of resolving the actual device locale)',
      () {
    final german = ProviderContainer(overrides: [
      localeProvider.overrideWithValue(null), // "system"
      effectiveLocaleProvider.overrideWithValue(const Locale('de')),
    ]);
    addTearDown(german.dispose);
    expect(german.read(rideNotificationCopyProvider).recordingTitle,
        'Fahrt wird aufgezeichnet');
    expect(german.read(rideNotificationCopyProvider).pause, 'Pause');
    expect(german.read(rideNotificationCopyProvider).stop, 'Beenden');

    final english = ProviderContainer(overrides: [
      localeProvider.overrideWithValue(null),
      effectiveLocaleProvider.overrideWithValue(const Locale('en')),
    ]);
    addTearDown(english.dispose);
    expect(english.read(rideNotificationCopyProvider).recordingTitle,
        'Recording ride');
  });

  test('rideNotificationCopyProvider carries the locale for number formatting',
      () {
    final german = ProviderContainer(overrides: [
      localeProvider.overrideWithValue(null),
      effectiveLocaleProvider.overrideWithValue(const Locale('de', 'DE')),
    ]);
    addTearDown(german.dispose);
    expect(german.read(rideNotificationCopyProvider).locale, 'de_DE');
  });

  group('rideForegroundServiceProvider picks the platform implementation', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('iOS → Live Activity', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(rideForegroundServiceProvider),
          isA<LiveActivityService>());
    });

    test('Android → foreground-task notification', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(rideForegroundServiceProvider),
          isA<ForegroundTaskService>());
    });
  });
}
