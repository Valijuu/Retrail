import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'features/shell/startup_failure_screen.dart';
import 'tracking/foreground_task_service.dart';
import 'tracking/live_activity_service.dart';
import 'tracking/ride_control_relay.dart';
import 'tracking/tracking_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait-only on every platform (backs up the Android manifest's
  // screenOrientation="portrait" and the iOS Info.plist orientation list).
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Match the removed 256 MB raster tile cache so revisited basemap tiles
  // render offline mid-ride (Android and iOS). Never block app start on cache
  // config — it throws on platforms without a native map (e.g. tests).
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
      preferencesRepositoryProvider.overrideWithValue(
        PreferencesRepository(prefs, photoRoot: docsDir.path),
      ),
      previewCacheDirProvider.overrideWithValue(docsDir),
    ],
  );

  // One-time notification channel + task options (localized channel name).
  ForegroundTaskService.init(
    channelName: container.read(rideNotificationCopyProvider).channelName,
  );

  // Relay recording-notification interactions (which arrive on the main isolate
  // via sendDataToMain) to the recording controller / deep-link.
  FlutterForegroundTask.addTaskDataCallback(
    (data) => rideControlRelay(container, data is String ? data : ''),
  );
  // Same relay for the iOS Live Activity's buttons and tap (Spec 6).
  listenForLiveActivityActions(
    liveActivityChannel,
    (id) => rideControlRelay(container, id),
  );

  if (await _openDatabase(container)) {
    _launchApp(container);
  } else {
    // A failing database open or migration used to end `main` here and leave
    // the launch screen up for good (#139): offer a retry instead.
    runApp(
      StartupFailureApp(
        retry: () async {
          // The failed open is cached in the database object: build a new one.
          container.invalidate(appDatabaseProvider);
          return _openDatabase(container);
        },
        onRecovered: () => _launchApp(container),
      ),
    );
  }
}

/// The first database access, so migrations run here. A fresh isolate can't be
/// recording yet, so any ride still missing its end time was cut off by a
/// killed process — close or drop it (issue #26). False when that fails.
Future<bool> _openDatabase(ProviderContainer container) async {
  try {
    await container.read(rideRepositoryProvider).finalizeUnfinishedRides();
    return true;
  } catch (_) {
    return false;
  }
}

void _launchApp(ProviderContainer container) {
  // Drop preview PNGs cached by an older renderer version (each version bump
  // leaves its predecessor's directory behind). Fire-and-forget: nothing
  // waits on it, and the current version's directory is never touched.
  unawaited(container.read(routePreviewCacheProvider).purgeOutdatedVersions());

  runApp(
    UncontrolledProviderScope(container: container, child: const RetrailApp()),
  );
}
