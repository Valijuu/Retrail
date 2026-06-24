import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/repositories/data_providers.dart';

/// Whether onboarding has been completed. `AsyncLoading` until the first value
/// arrives — the router shows the splash until then. Mirrors `StartupViewModel`.
final onboardingDoneProvider = StreamProvider<bool>(
  (ref) => ref.watch(preferencesRepositoryProvider).onboardingDone,
);

/// Set to drive a deep-link into the active-ride screen (the ongoing-ride
/// notification on Android, Live Activity on iOS). The router redirects to
/// `/ride` while true; the ride screen clears it. Mirrors `openRideSignal`.
final pendingRideDeepLinkProvider = StateProvider<bool>((ref) => false);
