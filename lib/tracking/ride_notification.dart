/// Ongoing-notification action ids shared between the foreground-service isolate
/// (which raises the button press) and the main isolate (which acts on it).
abstract final class RideNotificationIds {
  static const pause = 'ride_pause';
  static const resume = 'ride_resume';
  static const stop = 'ride_stop';

  /// Body tap → deep-link into the active ride (handled in the main isolate,
  /// not a [RideAction]).
  static const open = 'ride_open';
}

/// A control the user invoked from the recording notification.
enum RideAction { pause, resume, stop }

/// Maps a notification button id to a [RideAction], or null if unrecognized.
/// Pure, so the relay is unit-tested without the platform.
RideAction? rideActionFromId(String id) => switch (id) {
      RideNotificationIds.pause => RideAction.pause,
      RideNotificationIds.resume => RideAction.resume,
      RideNotificationIds.stop => RideAction.stop,
      _ => null,
    };
