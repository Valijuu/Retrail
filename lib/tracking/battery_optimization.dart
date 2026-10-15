import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/data_providers.dart';
import '../data/repositories/preferences_repository.dart';

/// Whether the OS may stop the recording to save battery (#68): aggressive
/// OEM power management (Samsung, Xiaomi, …) can kill the location service
/// with the screen off unless the app is exempt from battery optimization.
abstract interface class BatteryOptimizationService {
  Future<bool> isRestricted();
}

/// Android: restricted while the app is not on the battery-optimization
/// exemption list. The exemption is set by the user in the app's settings —
/// no REQUEST_IGNORE_BATTERY_OPTIMIZATIONS (Play only allows it for
/// messaging, safety, automation and device-companion apps).
class ForegroundTaskBatteryOptimization implements BatteryOptimizationService {
  const ForegroundTaskBatteryOptimization();

  @override
  Future<bool> isRestricted() async =>
      !await FlutterForegroundTask.isIgnoringBatteryOptimizations;
}

/// iOS keeps recording through background location + the Live Activity.
class NoBatteryOptimization implements BatteryOptimizationService {
  const NoBatteryOptimization();

  @override
  Future<bool> isRestricted() async => false;
}

final batteryOptimizationServiceProvider = Provider<BatteryOptimizationService>(
  (ref) => defaultTargetPlatform == TargetPlatform.android
      ? const ForegroundTaskBatteryOptimization()
      : const NoBatteryOptimization(),
);

/// The one-time hint at ride start asking to lift the battery restriction;
/// "Not now" is remembered so it never nags.
class BatteryHint {
  BatteryHint(this._battery, this._prefs);

  final BatteryOptimizationService _battery;
  final PreferencesRepository _prefs;

  Future<bool> shouldShow() async =>
      !_prefs.batteryHintDismissedNow && await _battery.isRestricted();

  Future<void> dismiss() => _prefs.setBatteryHintDismissed();
}

final batteryHintProvider = Provider<BatteryHint>(
  (ref) => BatteryHint(
    ref.watch(batteryOptimizationServiceProvider),
    ref.watch(preferencesRepositoryProvider),
  ),
);
