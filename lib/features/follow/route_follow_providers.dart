import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/follow_direction.dart';
import '../../domain/follow_tracker.dart';
import '../../domain/heading.dart' show LatLng;
import '../../domain/route_progress.dart';
import '../../tracking/location_fix.dart';
import '../../tracking/tracking_providers.dart';

/// Fixes less accurate than this don't move the follow position (the
/// follow-only feed doesn't pass through the recorder's GPS filter).
const double followMaxFixAccuracyM = 30;

/// A position older than this (a `lastKnown` seed, in follow-only mode or as
/// the recorder's first location) is ignored: it could place the rider
/// somewhere they left long ago and decide the direction from there.
const Duration followMaxSeedAge = Duration(minutes: 2);

/// Recent positions kept for the heading-up camera in follow-only mode.
const int _trailLength = 30;

/// Why the route turned to the opposite direction on its own (Spec 18): the
/// rider joined at its finish, or rode it backwards from elsewhere.
enum FollowReverseNotice { atFinish, detected }

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
    this.direction = FollowDirection.undecided,
    RouteTrack? orientedTrack,
    this.ridden = const [],
    this.reverseNotice,
  }) : orientedTrack = orientedTrack ?? track;

  /// The original route, whichever way it is ridden: the session identity
  /// [RouteFollowNotifier.pauseFeedFor] compares against.
  final RouteTrack track;

  /// Which way the rider follows [track] (Spec 18).
  final FollowDirection direction;

  /// Set once the direction was decided as reverse from the rider's
  /// position (not by a manual flip); the screens tell the rider once.
  final FollowReverseNotice? reverseNotice;

  /// [track] as ridden: its reversed copy when [isReversed]. [progress] is
  /// measured on it.
  final RouteTrack orientedTrack;

  /// The ridden parts of the route, in map order; empty while undecided. One
  /// per ridden part (a shortcut starts a new one), a part on a loop ridden
  /// across its start/finish split in two (Spec 18).
  final List<List<LatLng>> ridden;

  bool get isReversed => direction == FollowDirection.reverse;

  /// [progress] as the remaining text shows it: null while [direction] is
  /// undecided, so the text shows the whole route's length (Spec 18).
  RouteProgress? get displayProgress =>
      direction == FollowDirection.undecided ? null : progress;

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
    FollowDirection? direction,
    RouteTrack? orientedTrack,
    List<List<LatLng>>? ridden,
    FollowReverseNotice? reverseNotice,
  }) => RouteFollowState(
    track: track,
    recording: recording,
    rideTitle: rideTitle,
    progress: progress ?? this.progress,
    lastFix: lastFix ?? this.lastFix,
    trail: trail ?? this.trail,
    locationServiceEnabled:
        locationServiceEnabled ?? this.locationServiceEnabled,
    direction: direction ?? this.direction,
    orientedTrack: orientedTrack ?? this.orientedTrack,
    ridden: ridden ?? this.ridden,
    reverseNotice: reverseNotice ?? this.reverseNotice,
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

  /// Set when the follow-only fix stream errored; the next accepted fix
  /// clears it and turns the location banner off again.
  bool _feedFailed = false;

  /// The session's direction and ridden-range state machine (Spec 18).
  FollowTracker? _tracker;

  /// The intervals [RouteFollowState.ridden] was last cut from.
  List<(double, double)> _drawnRidden = const [];

  @override
  RouteFollowState? build() {
    ref.onDispose(_cancelFeed);
    ref.listen(rideTrackingStateProvider, (prev, next) {
      final recorder = next.asData?.value;
      // Not tracking: the location is the display-only seed, not progress.
      if (recorder == null || !recorder.isTracking) return;
      final fix = recorder.location;
      // The recorder re-emits every second with an unchanged location.
      if (fix == null || identical(fix, prev?.asData?.value.location)) return;
      // The recorder's location may be its stale last-known seed: it would
      // decide the direction from where the rider was long ago.
      if (state?.recording == true && _isFresh(fix)) onFix(fix);
    });
    return null;
  }

  void start({
    required List<LatLng> reference,
    String? rideTitle,
    required bool recording,
  }) {
    _cancelFeed();
    final distance = ref.read(distanceCalculatorProvider);
    final track = RouteTrack(reference, distance: distance);
    _tracker = FollowTracker.start(track, distance: distance);
    _drawnRidden = const [];
    state = RouteFollowState(
      track: track,
      recording: recording,
      rideTitle: rideTitle,
    );
  }

  void stop() {
    _cancelFeed();
    _tracker = null;
    _drawnRidden = const [];
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
    if (seed != null && _isFresh(seed)) onFix(seed);
    _fixSub = source.fixes.listen(onFix, onError: (Object _) {
      // Show the location banner rather than silently freezing the position.
      final cur = state;
      if (cur == null) return;
      _feedFailed = true;
      state = cur.copyWith(locationServiceEnabled: false);
    });
    _serviceSub = source.serviceEnabled.listen((on) {
      final cur = state;
      if (cur != null) state = cur.copyWith(locationServiceEnabled: on);
    }, onError: (Object _) {});
  }

  bool _isFresh(LocationFix fix) =>
      ref.read(followNowNanosProvider)() - fix.elapsedRealtimeNanos <=
      followMaxSeedAge.inMicroseconds * 1000;

  /// Follow-only: stops the GPS feed (app backgrounded). Progress is kept.
  void pauseFeed() => _cancelFeed();

  /// Pauses the feed only while [track]'s session is still the current one,
  /// so a closing follow screen can't stop a newer session's feed (#50).
  void pauseFeedFor(RouteTrack track) {
    if (identical(state?.track, track)) _cancelFeed();
  }

  void onFix(LocationFix fix) {
    final s = state;
    if (s == null || fix.accuracy > followMaxFixAccuracyM) return;
    final p = (lat: fix.latitude, lng: fix.longitude);
    final trail = [...s.trail, p];
    final recovered = _feedFailed;
    _feedFailed = false;
    final before = _tracker!;
    final tracker = before.next(p);
    _tracker = tracker;
    final turned =
        before.direction == FollowDirection.undecided &&
        tracker.direction == FollowDirection.reverse;
    state = _following(s, tracker).copyWith(
      reverseNotice: !turned
          ? null
          : before.hasJoined
          ? FollowReverseNotice.detected
          : FollowReverseNotice.atFinish,
      locationServiceEnabled: recovered ? true : null,
      lastFix: fix,
      trail: trail.length > _trailLength
          ? trail.sublist(trail.length - _trailLength)
          : trail,
    );
  }

  /// Rides the route the other way from the current position. Only once the
  /// rider has joined; while undecided it forces reverse.
  void flipDirection() {
    final s = state;
    final tracker = _tracker;
    if (s == null || tracker == null) return;
    final flipped = tracker.flip();
    if (identical(flipped, tracker)) return;
    _tracker = flipped;
    state = _following(s, flipped);
  }

  /// [s] with [tracker]'s direction and progress, and the ridden segments
  /// cut from its intervals once decided (reused while they are unchanged).
  RouteFollowState _following(RouteFollowState s, FollowTracker tracker) {
    final intervals = tracker.riddenIntervals;
    var ridden = s.ridden;
    if (tracker.direction != s.direction ||
        !listEquals(intervals, _drawnRidden)) {
      ridden = _riddenSegments(s.track, intervals, tracker.direction);
      _drawnRidden = intervals;
    }
    return s.copyWith(
      direction: tracker.direction,
      orientedTrack: tracker.orientedTrack,
      progress: tracker.progress,
      ridden: ridden,
    );
  }

  /// [intervals] of [track] as polylines in map order: on a reverse ride each
  /// runs backwards and their order flips.
  static List<List<LatLng>> _riddenSegments(
    RouteTrack track,
    List<(double, double)> intervals,
    FollowDirection direction,
  ) {
    final segments = [
      for (final (from, to) in intervals) track.segmentBetween(from, to),
    ]..removeWhere((segment) => segment.isEmpty);
    if (direction != FollowDirection.reverse) return segments;
    return [
      for (final segment in segments.reversed) segment.reversed.toList(),
    ];
  }

  void _cancelFeed() {
    _feedEpoch++;
    // resumeFeed re-reads the service state, so a stale error doesn't carry.
    _feedFailed = false;
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

/// Wall-clock "now" in nanoseconds for the follow seed's age check. Shares the
/// time source of [LocationFix.elapsedRealtimeNanos] (the fix's capture time,
/// see `fixFromPosition`), like `RideTracker`'s default clock. Overridden in
/// tests.
final followNowNanosProvider = Provider<int Function()>(
  (ref) => () => DateTime.now().microsecondsSinceEpoch * 1000,
);
