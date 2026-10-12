import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/data_providers.dart';
import '../features/shell/startup_provider.dart';
import 'ride_notification.dart';
import 'tracking_providers.dart';

/// Acts on a ride control raised outside the app UI — the Android recording
/// notification (via `flutter_foreground_task`) or the iOS Live Activity (via
/// the `retrail/live_activity` channel). One entry point, so both platforms
/// mean exactly the same thing by each [RideNotificationIds] id.
void rideControlRelay(ProviderContainer container, String id) {
  if (id == RideNotificationIds.open) {
    // Body tap → route into the active ride (router redirect handles it).
    container.read(pendingRideDeepLinkProvider.notifier).state = true;
    return;
  }
  final action = rideActionFromId(id);
  if (action == null) return;
  final controller = container.read(rideRecordingControllerProvider);
  switch (action) {
    case RideAction.pause:
      controller.pauseOrResume(false); // currently recording → pause
    case RideAction.resume:
      controller.pauseOrResume(true); // currently paused → resume
    case RideAction.stop:
      // Stopped outside the app, so no post-ride summary ran: park the ride
      // for the in-app "Ride saved · Add details" hint (#75). The tracker
      // records the ride id synchronously inside stop().
      final tracker = container.read(rideTrackerProvider);
      final wasRecording = tracker.state.isTracking;
      controller.stop(); // finalize the ride
      final rideId = tracker.lastCompletedRideId;
      if (wasRecording && rideId != null) {
        container
            .read(preferencesRepositoryProvider)
            .setPendingRideDetails(rideId);
      }
  }
}
