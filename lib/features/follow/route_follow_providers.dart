import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/follow_direction.dart';
import '../../domain/heading.dart' show LatLng;
import '../../domain/route_progress.dart';
import '../../tracking/location_fix.dart';
import '../../tracking/tracking_providers.dart';

/// Fixes less accurate than this don't move the follow position (the
/// follow-only feed doesn't pass through the recorder's GPS filter).
const double followMaxFixAccuracyM = 30;

/// A follow-only `lastKnown` seed older than this is ignored: it could place
/// the rider somewhere they left long ago.
const Duration followMaxSeedAge = Duration(minutes: 2);

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
    this.direction = FollowDirection.undecided,
    RouteTrack? orientedTrack,
    this.ridden = const [],
  }) : orientedTrack = orientedTrack ?? track;

  /// The original route, whichever way it is ridden: the session identity
  /// [RouteFollowNotifier.pauseFeedFor] compares against.
  final RouteTrack track;

  /// Which way the rider follows [track] (Spec 18).
  final FollowDirection direction;

  /// [track] as ridden: its reversed copy when [isReversed]. [progress] is
  /// measured on it.
  final RouteTrack orientedTrack;

  /// The ridden part of the route, in map order; empty while undecided.
  final List<LatLng> ridden;

  bool get isReversed => direction == FollowDirection.reverse;

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
    List<LatLng>? ridden,
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

  /// The session's route reversed, built once at [start].
  RouteTrack? _reversedTrack;

  /// While undecided: progress on the original and on the reversed route,
  /// and their along values at the join (Spec 18).
  RouteProgress? _fwdPrev, _revPrev;
  double _fwdJoin = 0, _revJoin = 0;

  /// The ridden stretch in original-route metres; null before the join.
  RiddenRange? _ridden;

  /// The range [RouteFollowState.ridden] was last cut from.
  RiddenRange? _drawnRidden;

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
    _resetDirection();
    final track = RouteTrack(
      reference,
      distance: ref.read(distanceCalculatorProvider),
    );
    _reversedTrack = track.reversed();
    state = RouteFollowState(
      track: track,
      recording: recording,
      rideTitle: rideTitle,
    );
  }

  void stop() {
    _cancelFeed();
    _resetDirection();
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
    if (seed != null && _isFreshSeed(seed)) onFix(seed);
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

  bool _isFreshSeed(LocationFix seed) =>
      ref.read(followNowNanosProvider)() - seed.elapsedRealtimeNanos <=
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
    final located = s.direction == FollowDirection.undecided
        ? _locateUndecided(s, p)
        : _locateDecided(s, p);
    state = located.copyWith(
      locationServiceEnabled: recovered ? true : null,
      lastFix: fix,
      trail: trail.length > _trailLength
          ? trail.sublist(trail.length - _trailLength)
          : trail,
    );
  }

  /// Tracks both directions until the join zone or 25 m of movement decides.
  RouteFollowState _locateUndecided(RouteFollowState s, LatLng p) {
    final track = s.track, reversed = _reversedTrack!;
    final wasJoined = _fwdPrev?.hasJoined ?? false;
    final fwd = track.locate(p, previous: _fwdPrev);
    final rev = reversed.locate(p, previous: _revPrev);
    _fwdPrev = fwd;
    _revPrev = rev;
    if (fwd == null || rev == null || !fwd.hasJoined) {
      return s.copyWith(progress: fwd);
    }
    var direction = FollowDirection.undecided;
    if (!wasJoined) {
      _fwdJoin = fwd.alongM;
      _revJoin = rev.alongM;
      _ridden = RiddenRange.at(fwd.alongM);
      direction = directionAtJoin(
        track,
        p,
        distance: ref.read(distanceCalculatorProvider),
      );
    } else {
      var range = _ridden!;
      if (!fwd.isOffRoute) range = range.extend(fwd.alongM);
      if (!rev.isOffRoute) range = range.extend(track.lengthM - rev.alongM);
      _ridden = range;
      direction = decideDirection(
        forwardAdvanceM: fwd.alongM - _fwdJoin,
        reverseAdvanceM: rev.alongM - _revJoin,
      );
    }
    if (direction == FollowDirection.undecided) {
      return s.copyWith(progress: fwd);
    }
    _fwdPrev = null;
    _revPrev = null;
    return _oriented(
      s,
      direction,
      direction == FollowDirection.reverse ? rev : fwd,
    );
  }

  /// Follows the decided direction and grows the ridden range while on route.
  RouteFollowState _locateDecided(RouteFollowState s, LatLng p) {
    final progress = s.orientedTrack.locate(p, previous: s.progress);
    if (progress != null && !progress.isOffRoute) {
      _ridden = _ridden!.extend(
        s.isReversed ? s.track.lengthM - progress.alongM : progress.alongM,
      );
    }
    return _oriented(s, s.direction, progress);
  }

  /// [s] riding [direction] at [progress], with the ridden segment drawn from
  /// the current range (the list is reused while the range is unchanged).
  RouteFollowState _oriented(
    RouteFollowState s,
    FollowDirection direction,
    RouteProgress? progress,
  ) {
    final range = _ridden!;
    final isReverse = direction == FollowDirection.reverse;
    var ridden = s.ridden;
    if (direction != s.direction ||
        range.loM != _drawnRidden?.loM ||
        range.hiM != _drawnRidden?.hiM) {
      final segment = s.track.segmentBetween(range.loM, range.hiM);
      ridden = isReverse ? segment.reversed.toList() : segment;
      _drawnRidden = range;
    }
    return s.copyWith(
      direction: direction,
      orientedTrack: isReverse ? _reversedTrack : s.track,
      progress: progress,
      ridden: ridden,
    );
  }

  /// Rides the route the other way from the current position. Only once the
  /// rider has joined; while undecided it forces reverse.
  void flipDirection() {
    final s = state;
    final old = s?.progress;
    final lastFix = s?.lastFix;
    if (s == null || old == null || !old.hasJoined || lastFix == null) return;
    final direction = s.isReversed
        ? FollowDirection.forward
        : FollowDirection.reverse;
    final newTrack = direction == FollowDirection.reverse
        ? _reversedTrack!
        : s.track;
    final lengthM = s.track.lengthM;
    final progress = newTrack.locate(
      (lat: lastFix.latitude, lng: lastFix.longitude),
      previous: RouteProgress(
        alongM: lengthM - old.alongM,
        remainingM: old.alongM,
        offsetM: old.offsetM,
        isOffRoute: false,
        isFinished: false,
        hasJoined: true,
      ),
    );
    _fwdPrev = null;
    _revPrev = null;
    state = _oriented(s, direction, progress);
  }

  void _resetDirection() {
    _reversedTrack = null;
    _fwdPrev = null;
    _revPrev = null;
    _fwdJoin = 0;
    _revJoin = 0;
    _ridden = null;
    _drawnRidden = null;
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
