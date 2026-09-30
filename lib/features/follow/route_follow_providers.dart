import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/heading.dart' show LatLng;
import '../../domain/route_progress.dart';
import '../../tracking/location_fix.dart';
import '../../tracking/tracking_providers.dart';

/// Fixes less accurate than this don't move the follow position (the
/// follow-only feed doesn't pass through the recorder's GPS filter).
const double followMaxFixAccuracyM = 30;

/// Recent positions kept for the heading-up camera in follow-only mode.
const int _trailLength = 30;

/// A reference route being followed (Spec 17), with the rider's progress.
class RouteFollowState {
  const RouteFollowState({
    required this.track,
    required this.recording,
    this.rideTitle,
    this.progress,
    this.lastFix,
    this.trail = const [],
    this.locationServiceEnabled = true,
  });

  final RouteTrack track;

  /// True when the repeat ride is being recorded (position from the recorder);
  /// false for follow-only (own foreground GPS feed).
  final bool recording;
  final String? rideTitle;
  final RouteProgress? progress;
  final LocationFix? lastFix;

  /// Recent positions, oldest first — the follow-only map's heading source.
  final List<LatLng> trail;
  final bool locationServiceEnabled;

  RouteFollowState copyWith({
    RouteProgress? progress,
    LocationFix? lastFix,
    List<LatLng>? trail,
    bool? locationServiceEnabled,
  }) => RouteFollowState(
    track: track,
    recording: recording,
    rideTitle: rideTitle,
    progress: progress ?? this.progress,
    lastFix: lastFix ?? this.lastFix,
    trail: trail ?? this.trail,
    locationServiceEnabled:
        locationServiceEnabled ?? this.locationServiceEnabled,
  );
}

/// Holds the followed reference (null = none, today's behaviour). Never
/// touches the recorder: in recording mode it only reads its live position.
class RouteFollowNotifier extends Notifier<RouteFollowState?> {
  StreamSubscription<LocationFix>? _fixSub;
  StreamSubscription<bool>? _serviceSub;

  /// Bumped on every feed cancel so a [resumeFeed] still awaiting its seed
  /// can tell it was stopped meanwhile.
  int _feedEpoch = 0;

  @override
  RouteFollowState? build() {
    ref.onDispose(_cancelFeed);
    ref.listen(rideTrackingStateProvider, (prev, next) {
      final fix = next.asData?.value.location;
      // The recorder re-emits every second with an unchanged location.
      if (fix == null || identical(fix, prev?.asData?.value.location)) return;
      if (state?.recording == true) onFix(fix);
    });
    return null;
  }

  void start({
    required List<LatLng> reference,
    String? rideTitle,
    required bool recording,
  }) {
    _cancelFeed();
    state = RouteFollowState(
      track: RouteTrack(
        reference,
        distance: ref.read(distanceCalculatorProvider),
      ),
      recording: recording,
      rideTitle: rideTitle,
    );
  }

  void stop() {
    _cancelFeed();
    state = null;
  }

  /// Follow-only: starts the foreground GPS feed (seeded with the last known
  /// fix). No-op in recording mode or when already running.
  Future<void> resumeFeed() async {
    final s = state;
    if (s == null || s.recording || _fixSub != null) return;
    final epoch = ++_feedEpoch;
    final source = ref.read(locationSourceProvider);
    LocationFix? seed;
    try {
      seed = await source.lastKnown();
    } catch (_) {
      // No seed: the live feed below still positions the rider.
    }
    // The service stream only reports changes, so seed its current value.
    var serviceOn = true;
    try {
      serviceOn = await ref
          .read(locationPermissionServiceProvider)
          .isLocationServiceEnabled();
    } catch (_) {}
    if (epoch != _feedEpoch || state == null) return;
    state = state!.copyWith(locationServiceEnabled: serviceOn);
    if (seed != null) onFix(seed);
    _fixSub = source.fixes.listen(onFix, onError: (Object _) {});
    _serviceSub = source.serviceEnabled.listen((on) {
      final cur = state;
      if (cur != null) state = cur.copyWith(locationServiceEnabled: on);
    }, onError: (Object _) {});
  }

  /// Follow-only: stops the GPS feed (app backgrounded). Progress is kept.
  void pauseFeed() => _cancelFeed();

  void onFix(LocationFix fix) {
    final s = state;
    if (s == null || fix.accuracy > followMaxFixAccuracyM) return;
    final p = (lat: fix.latitude, lng: fix.longitude);
    final trail = [...s.trail, p];
    state = s.copyWith(
      progress: s.track.locate(p, previous: s.progress),
      lastFix: fix,
      trail: trail.length > _trailLength
          ? trail.sublist(trail.length - _trailLength)
          : trail,
    );
  }

  void _cancelFeed() {
    _feedEpoch++;
    _fixSub?.cancel();
    _serviceSub?.cancel();
    _fixSub = null;
    _serviceSub = null;
  }
}

final routeFollowProvider =
    NotifierProvider<RouteFollowNotifier, RouteFollowState?>(
      RouteFollowNotifier.new,
    );
