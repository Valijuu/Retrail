import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/data_providers.dart';
import '../domain/distance_calculator.dart';
import '../features/settings/settings_providers.dart';
import '../l10n/app_localizations.dart';
import 'foreground_task_service.dart';
import 'geolocator_permission_service.dart';
import 'location_source.dart';
import 'ride_recording_controller.dart';
import 'ride_tracker.dart';
import 'ride_tracking_state.dart';

final distanceCalculatorProvider =
    Provider<DistanceCalculator>((ref) => const HaversineDistanceCalculator());

/// Process-lifetime ride recorder.
final rideTrackerProvider = Provider<RideTracker>((ref) {
  final tracker = RideTracker(
    ref.read(rideRepositoryProvider),
    ref.read(trackpointRepositoryProvider),
    ref.read(distanceCalculatorProvider),
  );
  ref.onDispose(tracker.dispose);
  return tracker;
});

/// Live tracking state — seeded from the tracker's current snapshot (the
/// `changes` stream does not replay), then following its updates.
final rideTrackingStateProvider = StreamProvider<RideTrackingState>((ref) async* {
  final tracker = ref.watch(rideTrackerProvider);
  yield tracker.state;
  yield* tracker.changes;
});

/// Whether a ride is currently being recorded.
final isTrackingProvider = Provider<bool>(
  (ref) => ref.watch(rideTrackingStateProvider).asData?.value.isTracking ?? false,
);

// ─── Spec 5B: platform GPS plumbing ──────────────────────────────────────────

/// Production GPS source (geolocator). Faked in recording-controller tests.
final locationSourceProvider =
    Provider<LocationSource>((ref) => const GeolocatorLocationSource());

/// Production permission/location-services seam (geolocator).
final locationPermissionServiceProvider = Provider<LocationPermissionService>(
    (ref) => const GeolocatorPermissionService());

/// Current-locale copy for the recording notification (the service has no
/// BuildContext). Falls back to English for unsupported locales — but reads
/// [effectiveLocaleProvider], not [localeProvider] directly: with the app
/// language set to "system" (the default), `localeProvider` is null — correct
/// for `MaterialApp`, which resolves that itself, but this provider has no
/// such resolution and would otherwise always fall through to English
/// regardless of the device's actual language.
final rideNotificationCopyProvider = Provider<RideNotificationCopy>((ref) {
  final locale = ref.watch(effectiveLocaleProvider);
  final l = lookupAppLocalizations(
      Locale(locale.languageCode == 'de' ? 'de' : 'en'));
  return RideNotificationCopy(
    channelName: l.notifChannelName,
    recordingTitle: l.notifRecordingTitle,
    pausedTitle: l.notifRecordingPausedTitle,
    pause: l.notifActionPause,
    resume: l.notifActionResume,
    stop: l.notifActionStop,
  );
});

/// Foreground service (keep-alive + ongoing notification).
final rideForegroundServiceProvider = Provider<RideForegroundService>(
  (ref) => ForegroundTaskService(() => ref.read(rideNotificationCopyProvider)),
);

/// Orchestrates permission gate → location source → tracker → foreground service.
final rideRecordingControllerProvider = Provider<RideRecordingController>((ref) {
  final controller = RideRecordingController(
    tracker: ref.watch(rideTrackerProvider),
    source: ref.watch(locationSourceProvider),
    permissions: ref.watch(locationPermissionServiceProvider),
    service: ref.watch(rideForegroundServiceProvider),
  );
  // Without this, a container torn down mid-ride (no stop() ever runs) leaked
  // the GPS subscription into a disposed tracker — same contract as
  // [rideTrackerProvider] above.
  ref.onDispose(controller.dispose);
  return controller;
});
