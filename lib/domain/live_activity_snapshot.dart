/// What the iOS Live Activity shows for the active ride, and when a new
/// snapshot is worth pushing to it (Spec 6 §B).
library;

import 'formatters.dart';

/// The content state of the ride Live Activity: everything the lock-screen /
/// Dynamic Island widget renders for one snapshot of the active ride.
class LiveActivityContent {
  const LiveActivityContent({
    required this.title,
    required this.distanceText,
    required this.isPaused,
    required this.elapsedSeconds,
    required this.snapshotEpochMs,
  });

  /// Localized headline — the recording or paused title.
  final String title;

  /// Ride distance, pre-formatted for the locale (e.g. `1.23 km`).
  final String distanceText;

  /// Whether the ride is paused (the widget freezes its timer while paused).
  final bool isPaused;

  /// Elapsed ride time in seconds at [snapshotEpochMs].
  final int elapsedSeconds;

  /// Wall-clock time (epoch ms) this snapshot was taken; lets the widget
  /// keep the timer ticking locally from [elapsedSeconds].
  final int snapshotEpochMs;
}

/// Builds the [LiveActivityContent] for the current ride state: picks
/// [pausedTitle] or [recordingTitle] by [isPaused], formats [distanceMetres]
/// for [locale], and stamps the snapshot with [nowEpochMs].
LiveActivityContent liveActivityContent({
  required bool isPaused,
  required int elapsedSeconds,
  required double distanceMetres,
  required String recordingTitle,
  required String pausedTitle,
  required String locale,
  required int nowEpochMs,
}) =>
    LiveActivityContent(
      title: isPaused ? pausedTitle : recordingTitle,
      distanceText: formatDistanceKm(distanceMetres, locale: locale),
      isPaused: isPaused,
      elapsedSeconds: elapsedSeconds,
      snapshotEpochMs: nowEpochMs,
    );
