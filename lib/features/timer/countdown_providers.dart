import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/data_providers.dart';
import '../../tracking/countdown_announcer.dart';
import '../../tracking/gps_fix_filter.dart';
import '../../tracking/gps_signal.dart';
import '../../tracking/ride_tracking_state.dart';
import '../../tracking/tracking_providers.dart';
import '../settings/settings_providers.dart';
import 'countdown_cue_controller.dart';

/// "Now" on the recorder's own clock, so "ready" means exactly "the recorder
/// would take this fix". Overridden in tests.
final gpsNowNanosProvider = Provider<int Function()>((ref) {
  final tracker = ref.watch(rideTrackerProvider);
  return () => tracker.nowNanos();
});

/// The countdown's GPS status (#69), from the fixes the armed recording
/// already streams. Re-evaluated on every tracking state change and once more
/// the moment a ready fix goes stale, so the row falls back to "searching"
/// when no fix follows (e.g. indoors).
final countdownGpsSignalProvider = Provider.autoDispose<GpsSignal>((ref) {
  final state =
      ref.watch(rideTrackingStateProvider).asData?.value ??
      const RideTrackingState();
  final now = ref.watch(gpsNowNanosProvider)();
  final fix = state.location;
  final signal = gpsSignal(
    fix: fix,
    serviceEnabled: state.locationServiceEnabled,
    nowNanos: now,
  );
  if (signal == GpsSignal.ready) {
    final ageNanos = now - fix!.elapsedRealtimeNanos;
    final staleIn = Duration(
      microseconds: (GpsFixFilter.maxFixAgeNanos - ageNanos) ~/ 1000 + 1,
    );
    final timer = Timer(staleIn, ref.invalidateSelf);
    ref.onDispose(timer.cancel);
  }
  return signal;
});

/// The voice + vibration behind the countdown cue (#81). Overridden in tests.
final countdownAnnouncerProvider = Provider<CountdownAnnouncer>(
  (ref) => PlatformCountdownAnnouncer(),
);

/// The countdown's cue: on unless switched off in the settings, spoken in the
/// app language.
final countdownCueControllerProvider = Provider<CountdownCueController>((ref) {
  final prefs = ref.watch(preferencesRepositoryProvider);
  return CountdownCueController(
    announcer: ref.watch(countdownAnnouncerProvider),
    enabled: () => prefs.countdownCueEnabledNow,
    locale: () => ref.read(effectiveLocaleProvider),
  );
});
