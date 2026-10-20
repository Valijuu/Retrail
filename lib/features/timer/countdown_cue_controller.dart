import 'dart:async';
import 'dart:ui' show Locale;

import '../../domain/countdown_cue.dart';
import '../../tracking/countdown_announcer.dart';

/// Turns the countdown's ticks into voice + vibration cues (#81): 5…1 from
/// the tick, "go" when the ride starts — at 0 or on Start now, so it is said
/// once either way. Does nothing while the cue is switched off in the
/// settings. Calls are fire-and-forget; a slow voice never delays a tick.
class CountdownCueController {
  CountdownCueController({
    required this._announcer,
    required this._enabled,
    required this._locale,
  });

  final CountdownAnnouncer _announcer;
  final bool Function() _enabled;
  final Locale Function() _locale;
  int? _lastCued;
  bool _started = false;

  /// The countdown opened: ready the voice for the app language.
  void begin() {
    _lastCued = null;
    _started = false;
    if (_enabled()) unawaited(_announcer.prepare(_locale()));
  }

  /// The countdown shows [secondsLeft]. A value seen again (a rebuild) is not
  /// repeated; after +5 the window is counted again.
  void onValue(int secondsLeft) {
    // After go nothing more is counted (a +5 tapped while the ride starts).
    if (_started || secondsLeft == _lastCued) return;
    final cue = countdownCueFor(secondsLeft);
    _lastCued = cue;
    if (cue != null && _enabled()) unawaited(_announcer.count(cue));
  }

  /// The ride starts.
  void onStart() {
    _started = true;
    if (_enabled()) unawaited(_announcer.go());
  }

  /// The countdown is gone: cut a cue still being spoken.
  void end() {
    if (_enabled()) unawaited(_announcer.stop());
  }
}
