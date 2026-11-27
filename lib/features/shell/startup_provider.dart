import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/data_providers.dart';

/// Whether onboarding has been completed. `AsyncLoading` until the first value
/// arrives — the router shows the splash until then. Mirrors `StartupViewModel`.
final onboardingDoneProvider = StreamProvider<bool>(
  (ref) => ref.watch(preferencesRepositoryProvider).onboardingDone,
);

/// Set to drive a deep-link into the active-ride screen (the ongoing-ride
/// notification on Android, Live Activity on iOS). The router redirects to
/// `/ride` while true; the ride screen clears it. Mirrors `openRideSignal`.
final pendingRideDeepLinkProvider = NotifierProvider<PendingRideDeepLink, bool>(
  PendingRideDeepLink.new,
);

/// Whether a deep link into the active ride is pending (the ongoing-ride
/// notification or Live Activity was tapped). Cleared once the ride screen takes it.
class PendingRideDeepLink extends Notifier<bool> {
  @override
  bool build() => false;

  /// Sets whether a deep link into the active ride is pending.
  void set(bool pending) => state = pending;
}
