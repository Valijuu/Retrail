import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'location_permission.dart';
import 'location_source.dart';
import 'ride_tracker.dart';

/// Platform permission + location-services seam (geolocator), behind an interface
/// so the recording orchestration is unit-testable without the platform.
abstract interface class LocationPermissionService {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();

  /// Escalates to background ("Always") authorization where the platform needs
  /// it for screen-off recording. iOS only: a second request upgrades
  /// whileInUse → Always (the location FGS already covers Android). Best-effort.
  Future<void> ensureBackgroundPermission();

  Future<void> openLocationSettings();
  Future<void> openAppSettings();
}

/// Foreground-service + ongoing-notification seam (flutter_foreground_task),
/// behind an interface for the same reason.
abstract interface class RideForegroundService {
  Future<void> start();
  Future<void> stop();
  Future<void> update({
    required bool isPaused,
    required int elapsedSeconds,
    required double distanceMetres,
  });

  /// Android 13+ POST_NOTIFICATIONS — without it the recording notification
  /// (and its controls) never show. Best-effort; recording still proceeds.
  Future<bool> ensureNotificationPermission();
}

/// Owns the platform lifecycle around a ride: gate permission, subscribe the
/// [LocationSource] into [RideTracker], and run the foreground service. The
/// pure-Dart [RideTracker] stays the single source of truth the UI reads.
class RideRecordingController {
  RideRecordingController({
    required RideTracker tracker,
    required LocationSource source,
    required LocationPermissionService permissions,
    required RideForegroundService service,
  })  : _tracker = tracker,
        _source = source,
        _permissions = permissions,
        _service = service;

  // ignore_for_file: prefer_initializing_formals — public named params kept
  // (callers shouldn't pass private field names like `_tracker:`).
  final RideTracker _tracker;
  final LocationSource _source;
  final LocationPermissionService _permissions;
  final RideForegroundService _service;

  StreamSubscription<void>? _fixSub;
  StreamSubscription<void>? _stateSub;

  /// Runs the permission gate **without** starting recording: notification +
  /// location permission (requesting once if undecided) and, on success, the
  /// background escalation. Returns the outcome so the Start-tracking press can
  /// prompt up front and only continue to the countdown when granted — mirroring
  /// the original `HomePage` flow, where permission is resolved before navigating
  /// to the timer. Idempotent with [start]'s own gate (a granted re-check is a
  /// no-op prompt-wise), so [start] stays correct as a defense-in-depth fallback.
  Future<LocationStartAction> prepare() => _runGate();

  /// Notification permission + location-services + location permission, returning
  /// the gate outcome. On [LocationStartAction.proceed] it also escalates to
  /// background ("Always") auth where the platform needs it for screen-off
  /// recording (iOS); no-op on Android. Shared by [prepare] and [start].
  Future<LocationStartAction> _runGate() async {
    await _service.ensureNotificationPermission();

    final serviceEnabled = await _permissions.isLocationServiceEnabled();
    var permission = await _permissions.checkPermission();
    var action =
        permissionGateDecision(serviceEnabled: serviceEnabled, permission: permission);

    if (action == LocationStartAction.requestPermission) {
      permission = await _permissions.requestPermission();
      action = permissionGateDecision(
          serviceEnabled: serviceEnabled, permission: permission);
    }
    if (action != LocationStartAction.proceed) return action;

    // Best-effort — foreground recording proceeds regardless.
    await _permissions.ensureBackgroundPermission();
    return action;
  }

  /// Resolves permission (requesting once if undecided), and on success starts
  /// the source + service + tracker. Returns the gate outcome so the UI can show
  /// the rationale / enable-location prompt when not [LocationStartAction.proceed].
  Future<LocationStartAction> start() async {
    if (_tracker.state.isTracking) return LocationStartAction.proceed;

    final action = await _runGate();
    if (action != LocationStartAction.proceed) return action;

    // Centre the map on the last-known fix immediately (display only — it may be
    // stale on a cold start, which the recording path would drop), then stream
    // fresh fixes. seedLocation no-ops once a real fix has set the position.
    final seed = await _source.lastKnown();
    if (seed != null) _tracker.seedLocation(seed);
    _fixSub = _source.fixes.listen(_tracker.onLocationReceived);
    // Keep the ongoing notification's live stats in sync.
    _stateSub = _tracker.changes.listen((s) => _service.update(
          isPaused: s.isPaused,
          elapsedSeconds: s.elapsedSeconds,
          distanceMetres: s.distanceMetres,
        ));

    await _service.start();
    _tracker.startTracking();
    return LocationStartAction.proceed;
  }

  void pauseOrResume(bool isPaused) =>
      isPaused ? _tracker.resume() : _tracker.pause();

  /// Stops recording: cancels the subscriptions, finalizes the ride, and tears
  /// down the service. Idempotent with the in-app/notification stop paths.
  Future<void> stop() async {
    await _fixSub?.cancel();
    _fixSub = null;
    await _stateSub?.cancel();
    _stateSub = null;
    _tracker.stopTracking();
    await _service.stop();
  }

  Future<void> openLocationSettings() => _permissions.openLocationSettings();
  Future<void> openAppSettings() => _permissions.openAppSettings();
}
