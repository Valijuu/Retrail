import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:maplibre/maplibre.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/repositories/data_providers.dart';
import 'data/repositories/preferences_repository.dart';
import 'features/active_ride/active_ride_providers.dart';
import 'features/shell/startup_provider.dart';
import 'tracking/foreground_task_service.dart';
import 'tracking/ride_notification.dart';
import 'tracking/tracking_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Match the removed 256 MB raster tile cache so revisited basemap tiles
  // render offline mid-ride. Never block app start on cache config — the call
  // throws UnimplementedError on non-Android (same as the map widget).
  try {
    final offline = await OfflineManager.createInstance();
    await offline.setMaximumAmbientCacheSize(bytes: 256 * 1024 * 1024);
    offline.dispose();
  } catch (_) {
    // Cache config is best-effort; continue startup regardless.
  }

  // Foreground-service ↔ main-isolate channel must be opened before runApp so
  // notification-button taps relayed via sendDataToMain are received.
  FlutterForegroundTask.initCommunicationPort();

  final prefs = await SharedPreferences.getInstance();
  final docsDir = await getApplicationDocumentsDirectory();
  await initializeDateFormatting();

  final container = ProviderContainer(
    overrides: [
      preferencesRepositoryProvider
          .overrideWithValue(PreferencesRepository(prefs)),
      previewCacheDirProvider.overrideWithValue(docsDir),
    ],
  );

  // One-time notification channel + task options (localized channel name).
  ForegroundTaskService.init(
    channelName: container.read(rideNotificationCopyProvider).channelName,
  );

  // Relay recording-notification interactions (which arrive on the main isolate
  // via sendDataToMain) to the recording controller / deep-link.
  FlutterForegroundTask.addTaskDataCallback((data) {
    final id = data is String ? data : '';
    if (id == RideNotificationIds.open) {
      // Body tap → route into the active ride (router redirect handles it).
      container.read(pendingRideDeepLinkProvider.notifier).state = true;
      return;
    }
    final controller = container.read(rideRecordingControllerProvider);
    switch (rideActionFromId(id)) {
      case RideAction.pause:
        controller.pauseOrResume(false); // currently recording → pause
      case RideAction.resume:
        controller.pauseOrResume(true); // currently paused → resume
      case RideAction.stop:
        controller.stop(); // finalize the ride
      case null:
        break;
    }
  });

  runApp(UncontrolledProviderScope(
    container: container,
    child: const RetrailApp(),
  ));
}
