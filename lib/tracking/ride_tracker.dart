import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;

import '../data/db/app_database.dart';
import '../data/repositories/ride_repository.dart';
import '../data/repositories/trackpoint_repository.dart';
import '../domain/activity_type.dart';
import '../domain/distance_calculator.dart';
import 'location_fix.dart';
import 'ride_tracking_state.dart';

/// Holds all live ride-recording state and the GPS recording pipeline.
///
/// A process-lifetime singleton (not tied to the UI) so recording keeps running
/// when the screen is locked or the user navigates away while the platform
/// location source keeps feeding fixes into [onLocationReceived].
///
/// Pure Dart — no Flutter imports. Ported 1:1 from the original Kotlin
/// `RideTracker`, including the 9-stage GPS filter and its constants.
class RideTracker {
  RideTracker(
    this._rideRepository,
    this._trackpointRepository,
    this._calc, {
    int Function()? nowMs,
    int Function()? nowNanos,
  }) {
    this.nowMs = nowMs ?? _defaultNowMs;
    this.nowNanos = nowNanos ?? _defaultNowNanos;
  }

  final RideRepository _rideRepository;
  final TrackpointRepository _trackpointRepository;
  final DistanceCalculator _calc;

  // ─── Filter constants (unchanged from the original) ──────────────────────
  static const double _accuracyThresholdM = 35;
  static const double _minDistanceM = 8.0;
  static const double _minSpeedMs = 0.5;
  static const double _stationarySpeedMs = 0.8;
  static const int _maxFixAgeNanos = 5000000000; // 5 s
  static const double _maxSpeedMs = 50.0; // ~180 km/h

  /// Monotonic clock matching [LocationFix.elapsedRealtimeNanos]. Overridable in
  /// tests; production uses a process [Stopwatch]. Used by the freshness filter.
  late int Function() nowNanos;

  /// Wall-clock "now" in epoch ms for ride/trackpoint timestamps.
  late int Function() nowMs;

  // ─── Live state (mirrors the original MutableStateFlows) ─────────────────
  LocationFix? _location;
  bool _isTracking = false;
  List<RoutePoint> _trackPoints = const [];
  double _distanceMetres = 0.0;
  double? _speedKmh;
  int _elapsedSeconds = 0;
  bool _isPaused = false;
  ActivityType? _activityType;

  int? _activeRideId;
  int? _lastCompletedRideId;
  String? _pendingActivityType;
  LocationFix? _lastRecordedLocation;
  LocationFix? _lastSpeedLocation;
  Timer? _elapsedTimer;

  final StreamController<RideTrackingState> _states =
      StreamController<RideTrackingState>.broadcast();

  /// Current immutable snapshot.
  RideTrackingState get state => RideTrackingState(
        location: _location,
        isTracking: _isTracking,
        trackPoints: List.unmodifiable(_trackPoints),
        distanceMetres: _distanceMetres,
        speedKmh: _speedKmh,
        elapsedSeconds: _elapsedSeconds,
        isPaused: _isPaused,
        activityType: _activityType,
      );

  /// Emits on every state change (for the UI / Riverpod). Broadcast and does NOT
  /// replay — a new subscriber should seed from [state] then append [changes].
  Stream<RideTrackingState> get changes => _states.stream;

  /// The id of the most recently stopped ride (until it is saved or discarded).
  /// Read-only; lets the active-ride screen generate its preview after save.
  int? get lastCompletedRideId => _lastCompletedRideId;

  void _emit() => _states.add(state);

  /// Sets the activity type for the next ride started. Commits [_activityType]
  /// immediately (not only in [startTracking]) so the active-ride map renders
  /// the chosen activity's marker from the first frame — the ride screen builds
  /// before [startTracking] runs, so a late commit shows the previous activity.
  void setPendingActivityType(String? typeId) {
    _pendingActivityType = typeId;
    _activityType = ActivityType.fromId(typeId);
  }

  void startTracking() {
    _isTracking = true;
    _isPaused = false;
    _activityType = ActivityType.fromId(_pendingActivityType);
    _emit();
    unawaited(_beginRide());
  }

  Future<void> _beginRide() async {
    final now = nowMs();
    final rideId = await _rideRepository.insert(RidesCompanion.insert(
      typ: Value(_pendingActivityType),
      startTime: Value(now),
      date: Value(now),
    ));
    _activeRideId = rideId;
    _lastRecordedLocation = null;
    _trackPoints = const [];
    _distanceMetres = 0.0;
    _speedKmh = null;
    _elapsedSeconds = 0;
    _startElapsedTimer();
    _emit();
  }

  void stopTracking() {
    final rideId = _activeRideId;
    if (rideId == null) return;
    _lastCompletedRideId = rideId;
    _cancelElapsedTimer();
    unawaited(_endRide(rideId));
  }

  Future<void> _endRide(int rideId) async {
    await _rideRepository.updateEndTime(rideId, nowMs());
    _activeRideId = null;
    _isTracking = false;
    _isPaused = false;
    _emit();
  }

  /// Pauses recording: freezes the timer and stops recording without ending the
  /// ride. No-op when not tracking or already paused.
  void pause() {
    if (!_isTracking || _isPaused) return;
    _isPaused = true;
    _cancelElapsedTimer();
    _emit();
  }

  /// Resumes a paused ride. Clears [_lastRecordedLocation] so the pause gap isn't
  /// counted as one big distance jump. No-op when not tracking or not paused.
  void resume() {
    if (!_isTracking || !_isPaused) return;
    _isPaused = false;
    _lastRecordedLocation = null;
    _startElapsedTimer();
    _emit();
  }

  void saveRideDetails(String? description, String? comment,
      {bool isFavorite = false}) {
    final rideId = _lastCompletedRideId;
    if (rideId == null) return;
    unawaited(() async {
      await _rideRepository.updateRideDetails(rideId, description, comment);
      await _rideRepository.updateFavorite(rideId, isFavorite);
    }());
  }

  /// Discards the last stopped ride entirely (CASCADE removes its trackpoints)
  /// and resets live state.
  void discardRide() {
    final rideId = _lastCompletedRideId;
    if (rideId == null) return;
    _lastCompletedRideId = null;
    _trackPoints = const [];
    _distanceMetres = 0.0;
    _elapsedSeconds = 0;
    _emit();
    unawaited(_rideRepository.deleteById(rideId));
  }

  /// Seeds the live marker / camera position from the device's last-known fix
  /// when a ride starts, so the map centres on the rider's area immediately
  /// instead of null island (0,0) while the first fresh GPS fix is acquired
  /// (slow on a cold start). Display only — it bypasses the freshness/accuracy
  /// filters and is never recorded as a trackpoint. No-op once a real fix has
  /// already set the location, so it can't regress a fresher position.
  void seedLocation(LocationFix fix) {
    if (_location != null) return;
    _location = fix;
    _emit();
  }

  void onLocationReceived(LocationFix fix) {
    // 0. Freshness: drop stale cached fixes before any state update.
    if (nowNanos() - fix.elapsedRealtimeNanos > _maxFixAgeNanos) return;

    // Always update the live marker + speed (shown regardless of recording state).
    _location = fix;
    _speedKmh = _computeSpeedKmh(fix);
    _lastSpeedLocation = fix;
    _emit();

    if (_isPaused) return;

    final rideId = _activeRideId;
    if (rideId == null) return;

    // 1. Discard low-accuracy fixes.
    if (fix.accuracy > _accuracyThresholdM) return;

    final last = _lastRecordedLocation;
    // First point: record the start location immediately, even standing still.
    // The stationary / displacement / speed guards below only make sense against
    // a previous point — applying them here would drop the start fix of a ride
    // begun at rest, leaving a no-movement ride with zero points ("No route").
    if (last == null) {
      _recordPoint(rideId, fix);
      return;
    }

    // 1b. Stationary guard: trustworthy near-zero provider speed → skip.
    if (fix.hasSpeed && fix.speed < _stationarySpeedMs) return;

    final distance = _calc.distanceBetween(
        last.latitude, last.longitude, fix.latitude, fix.longitude);
    final elapsedS =
        (fix.elapsedRealtimeNanos - last.elapsedRealtimeNanos) / 1000000000.0;

    // 2. Outlier guard: physically impossible implied speed → drop, keep last.
    if (elapsedS > 0.0 && distance / elapsedS > _maxSpeedMs) return;

    // 3. Displacement must exceed the accuracy margin of both readings.
    final requiredDisplacement =
        math.max(_minDistanceM, math.max(last.accuracy, fix.accuracy));
    if (distance < requiredDisplacement) return;

    // 4. Implied speed must indicate real movement (catches slow drift).
    if (elapsedS > 0.0 && distance / elapsedS < _minSpeedMs) return;

    _distanceMetres += distance;
    _recordPoint(rideId, fix);
  }

  /// Appends [fix] to the recorded route and persists it. Callers have already
  /// run the filter stages appropriate to the fix (the first point bypasses the
  /// stationary/displacement guards — see [onLocationReceived]).
  void _recordPoint(int rideId, LocationFix fix) {
    _lastRecordedLocation = fix;
    _trackPoints = [..._trackPoints, (lat: fix.latitude, lng: fix.longitude)];
    _emit();

    unawaited(_trackpointRepository.insert(TrackpointsCompanion.insert(
      rideId: rideId,
      latitude: fix.latitude,
      longitude: fix.longitude,
      timestamp: nowMs(),
      speed: Value(fix.hasSpeed ? fix.speed : null),
    )));
  }

  /// Prefer the provider's speed; else fall back to displacement / time between
  /// the last two fixes.
  double? _computeSpeedKmh(LocationFix fix) {
    if (fix.hasSpeed) return fix.speed * 3.6;
    final prev = _lastSpeedLocation;
    if (prev == null) return null;
    final elapsedS =
        (fix.elapsedRealtimeNanos - prev.elapsedRealtimeNanos) / 1000000000.0;
    if (elapsedS <= 0.0) return null;
    final distance = _calc.distanceBetween(
        prev.latitude, prev.longitude, fix.latitude, fix.longitude);
    return distance / elapsedS * 3.6;
  }

  void _startElapsedTimer() {
    _cancelElapsedTimer();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds += 1;
      _emit();
    });
  }

  void _cancelElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }

  void dispose() {
    _cancelElapsedTimer();
    _states.close();
  }

  static int _defaultNowMs() => DateTime.now().millisecondsSinceEpoch;

  // Wall-clock "now" in nanoseconds. Must share the same time source as the
  // fixes' [LocationFix.elapsedRealtimeNanos] (geolocator's real capture
  // timestamp) so the freshness filter compares like-for-like and still catches
  // a minutes-old cached fix.
  static int _defaultNowNanos() => DateTime.now().microsecondsSinceEpoch * 1000;
}
