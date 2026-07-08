import 'dart:ui' show Brightness;

import '../../map/route_preview_cache.dart';
import '../../tracking/ride_tracker.dart';

/// Thin, testable seam over [RideTracker] + [RoutePreviewCache] for the
/// active-ride screen. Owns the save→generate-preview sequence so the widget
/// stays declarative and the orchestration can be unit-tested without pumping
/// the screen. Adds no new tracker state; delegates intents 1:1.
class ActiveRideController {
  ActiveRideController(this._tracker, this._cache,
      {Brightness Function()? currentBrightness})
      : _currentBrightness = currentBrightness ?? (() => Brightness.light);

  final RideTracker _tracker;
  final RoutePreviewCache _cache;

  /// The app's current display brightness, so the save-time preview is
  /// pre-generated in the theme the user is in. Defaults to light when unset.
  final Brightness Function() _currentBrightness;

  /// Starts a ride unless one is already active. The guard mirrors the
  /// original `MapViewModel.onPermissionResult` (`if (isTracking) return`) and
  /// prevents the notification/deep-link reopen from orphaning the in-progress
  /// ride and starting a second one.
  void startRide() {
    if (_tracker.state.isTracking) return;
    _tracker.startTracking();
  }

  void stopRide() => _tracker.stopTracking();
  void discardRide() => _tracker.discardRide();

  /// Pause when running, resume when paused — given the current [isPaused].
  void pauseOrResume(bool isPaused) =>
      isPaused ? _tracker.resume() : _tracker.pause();

  /// How long the preview render waits after save. Saving navigates home with
  /// a 220 ms exit transition; the render's tile decodes + PNG encode run on
  /// the UI isolate and janked those frames (visible as a stutter/blink).
  /// Deferring past the transition costs nothing — the history card falls back
  /// to the cache-warm path on first view anyway.
  static const previewDelay = Duration(milliseconds: 450);

  /// Persists ride details, then generates the preview PNG once for the
  /// just-stopped ride (online snapshot or offline flat sketch — the cache's
  /// renderer decides), deferred by [previewDelay] so the render never
  /// competes with the exit transition. No-op preview when there is no
  /// completed ride or route.
  Future<void> saveRide({
    String? title,
    String? comment,
    bool favorite = false,
  }) async {
    final rideId = _tracker.lastCompletedRideId;
    final points = _tracker.state.trackPoints;
    _tracker.saveRideDetails(title, comment, isFavorite: favorite);
    if (rideId != null && points.isNotEmpty) {
      await Future<void>.delayed(previewDelay);
      await _cache.ensurePreview(rideId, points,
          brightness: _currentBrightness());
    }
  }
}
