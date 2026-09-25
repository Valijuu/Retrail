import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/services.dart';

import '../data/repositories/ride_repository.dart' show NowMs;
import '../domain/live_activity_snapshot.dart';
import 'foreground_task_service.dart';
import 'ride_recording_controller.dart';

/// Channel to `LiveActivityBridge.swift` (Spec 6 §A). Dart → Swift:
/// `isSupported`, `start`, `update`, `end`; Swift → Dart: `action` with a
/// `RideNotificationIds` id.
const liveActivityChannel = MethodChannel('retrail/live_activity');

/// The Live Activity's accent colors, as ARGB ints from `AppColors.primary`
/// (light + dark), so the Swift widget uses no color of its own.
class LiveActivityAccents {
  const LiveActivityAccents({required this.light, required this.dark});

  final int light;
  final int dark;
}

/// Forwards `action` calls from the Live Activity (buttons / tap) to
/// [onAction]; anything else on the channel is ignored.
void listenForLiveActivityActions(
  MethodChannel channel,
  void Function(String id) onAction,
) {
  channel.setMethodCallHandler((call) async {
    final id = call.arguments;
    if (call.method == 'action' && id is String) onAction(id);
  });
}

/// iOS [RideForegroundService]: shows the active ride as a Live Activity
/// instead of Android's ongoing notification. Background recording on iOS
/// comes from `geolocator`, so this is display + controls only.
///
/// Every channel call is best-effort: an unsupported iOS, Live Activities
/// switched off, or any platform error leaves the service inactive and never
/// reaches the recording.
class LiveActivityService implements RideForegroundService {
  LiveActivityService(this._channel, this._copy, this._accents, {NowMs? now})
    : _now = now ?? _wallClockMs;

  final MethodChannel _channel;
  final RideNotificationCopy Function() _copy;
  final LiveActivityAccents _accents;
  final NowMs _now;

  /// Content last sent to the running activity; null while none runs.
  LiveActivityContent? _last;

  /// A ride is recording, so an activity should be showing — even if the
  /// start failed (e.g. `Activity.request` throws while the phone is locked).
  bool _wanted = false;

  /// When the last start was attempted, for throttling retries.
  int _lastStartAttemptMs = 0;

  /// A failed start is retried on a later update at most this often.
  static const _startRetryIntervalMs = 30 * 1000;

  static int _wallClockMs() => DateTime.now().millisecondsSinceEpoch;

  /// Live Activities need no notification permission.
  @override
  Future<bool> ensureNotificationPermission() async => true;

  @override
  Future<void> start() async {
    _wanted = true;
    final copy = _copy();
    await _tryStart(
      _content(
        isPaused: false,
        elapsedSeconds: 0,
        distanceMetres: 0,
        copy: copy,
      ),
    );
  }

  Future<void> _tryStart(LiveActivityContent content) async {
    _lastStartAttemptMs = _now();
    if (await _invoke<bool>('isSupported') != true) return;
    final copy = _copy();
    final started = await _send('start', {
      'attributes': {
        'pauseLabel': copy.pause,
        'resumeLabel': copy.resume,
        'stopLabel': copy.stop,
        'accentLight': _accents.light,
        'accentDark': _accents.dark,
      },
      'content': content.toMap(),
    });
    // A stop that landed while the start was in flight wins.
    if (started && _wanted) _last = content;
  }

  @override
  Future<void> update({
    required bool isPaused,
    required int elapsedSeconds,
    required double distanceMetres,
  }) async {
    final next = _content(
      isPaused: isPaused,
      elapsedSeconds: elapsedSeconds,
      distanceMetres: distanceMetres,
      copy: _copy(),
    );
    final last = _last;
    if (last == null) {
      if (_wanted && _now() - _lastStartAttemptMs >= _startRetryIntervalMs) {
        await _tryStart(next);
      }
      return;
    }
    if (!shouldPush(last, next)) return;
    _last = next;
    await _send('update', next.toMap());
  }

  @override
  Future<void> stop() async {
    _wanted = false;
    if (_last == null) return;
    _last = null;
    await _send('end');
  }

  LiveActivityContent _content({
    required bool isPaused,
    required int elapsedSeconds,
    required double distanceMetres,
    required RideNotificationCopy copy,
  }) => liveActivityContent(
    isPaused: isPaused,
    elapsedSeconds: elapsedSeconds,
    distanceMetres: distanceMetres,
    recordingTitle: copy.recordingTitle,
    pausedTitle: copy.pausedTitle,
    locale: copy.locale,
    nowEpochMs: _now(),
  );

  /// Invokes [method]; true when it completed without a platform error.
  Future<bool> _send(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
      return true;
    } on Exception catch (e) {
      _log(method, e);
      return false;
    }
  }

  Future<T?> _invoke<T>(String method) async {
    try {
      return await _channel.invokeMethod<T>(method);
    } on Exception catch (e) {
      _log(method, e);
      return null;
    }
  }

  // PlatformException / MissingPluginException both implement Exception.
  static void _log(String method, Exception e) {
    if (kDebugMode) debugPrint('LiveActivity $method failed: $e');
  }
}
