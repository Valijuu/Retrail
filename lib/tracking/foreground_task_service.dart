import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../domain/formatters.dart';
import 'ride_notification.dart';
import 'ride_recording_controller.dart';

/// Localized copy for the recording notification, resolved from the current
/// locale in the provider layer (the service runs without a BuildContext).
class RideNotificationCopy {
  const RideNotificationCopy({
    required this.channelName,
    required this.recordingTitle,
    required this.pausedTitle,
    required this.pause,
    required this.resume,
    required this.stop,
  });

  final String channelName;
  final String recordingTitle;
  final String pausedTitle;
  final String pause;
  final String resume;
  final String stop;
}

/// Entry point for the foreground-service isolate.
///
/// MUST be a top-level function annotated `@pragma('vm:entry-point')` — without
/// it the release build tree-shakes it away and the service silently fails to
/// start. The handler only *relays* notification interactions to the main
/// isolate; all recording stays in the main isolate's [RideTracker].
@pragma('vm:entry-point')
void startRideTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_RideTaskHandler());
}

class _RideTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationButtonPressed(String id) =>
      FlutterForegroundTask.sendDataToMain(id);

  @override
  void onNotificationPressed() =>
      FlutterForegroundTask.sendDataToMain(RideNotificationIds.open);
}

/// Production [RideForegroundService] over `flutter_foreground_task`: keeps the
/// process alive (screen-off recording) and renders the ongoing notification.
class ForegroundTaskService implements RideForegroundService {
  ForegroundTaskService(this._copy);

  /// Resolves current-locale copy lazily (locale can change between rides).
  final RideNotificationCopy Function() _copy;

  static const _channelId = 'ride_tracking_v2';

  /// One-time init of the notification channel + task options. Channel is
  /// `DEFAULT` importance but silent — a LOW channel hides the control in the
  /// silent shade (the original's hard-won lesson).
  static void init({required String channelName}) {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _channelId,
        channelName: channelName,
        channelImportance: NotificationChannelImportance.DEFAULT,
        priority: NotificationPriority.DEFAULT,
        enableVibration: false,
        playSound: false,
        onlyAlertOnce: true,
        showBadge: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  @override
  Future<bool> ensureNotificationPermission() async {
    final result = await FlutterForegroundTask.requestNotificationPermission();
    return result == NotificationPermission.granted;
  }

  @override
  Future<void> start() async {
    final c = _copy();
    await FlutterForegroundTask.startService(
      serviceId: 1,
      serviceTypes: const [ForegroundServiceTypes.location],
      notificationTitle: c.recordingTitle,
      notificationText: _body(elapsedSeconds: 0, distanceMetres: 0),
      notificationButtons: _buttons(isPaused: false, copy: c),
      callback: startRideTaskCallback,
    );
  }

  @override
  Future<void> update({
    required bool isPaused,
    required int elapsedSeconds,
    required double distanceMetres,
  }) async {
    if (!await FlutterForegroundTask.isRunningService) return;
    final c = _copy();
    await FlutterForegroundTask.updateService(
      notificationTitle: isPaused ? c.pausedTitle : c.recordingTitle,
      notificationText:
          _body(elapsedSeconds: elapsedSeconds, distanceMetres: distanceMetres),
      notificationButtons: _buttons(isPaused: isPaused, copy: c),
    );
  }

  @override
  Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  static String _body({
    required int elapsedSeconds,
    required double distanceMetres,
  }) =>
      '${formatElapsed(elapsedSeconds)} · '
      '${(distanceMetres / 1000.0).toStringAsFixed(2)} km';

  // Toggle action reflects state: Resume when paused, Pause when recording.
  static List<NotificationButton> _buttons({
    required bool isPaused,
    required RideNotificationCopy copy,
  }) =>
      [
        if (isPaused)
          NotificationButton(id: RideNotificationIds.resume, text: copy.resume)
        else
          NotificationButton(id: RideNotificationIds.pause, text: copy.pause),
        NotificationButton(id: RideNotificationIds.stop, text: copy.stop),
      ];
}
