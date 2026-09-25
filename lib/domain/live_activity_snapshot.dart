/// What the iOS Live Activity shows for the active ride, and when a new
/// snapshot is worth pushing to it (Spec 6 §B).
library;

import 'formatters.dart';

// Channel-contract keys of [LiveActivityContent.toMap] — the Swift
// ActivityKit side decodes the content state by exactly these names.
const _titleKey = 'title';
const _distanceTextKey = 'distanceText';
const _isPausedKey = 'isPaused';
const _elapsedSecondsKey = 'elapsedSeconds';
const _snapshotEpochMsKey = 'snapshotEpochMs';

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

  /// The content state as sent over the platform channel to the Swift
  /// Live Activity; the keys are a contract with the native side.
  Map<String, Object> toMap() => {
    _titleKey: title,
    _distanceTextKey: distanceText,
    _isPausedKey: isPaused,
    _elapsedSecondsKey: elapsedSeconds,
    _snapshotEpochMsKey: snapshotEpochMs,
  };

  @override
  bool operator ==(Object other) =>
      other is LiveActivityContent &&
      other.title == title &&
      other.distanceText == distanceText &&
      other.isPaused == isPaused &&
      other.elapsedSeconds == elapsedSeconds &&
      other.snapshotEpochMs == snapshotEpochMs;

  @override
  int get hashCode => Object.hash(
    title,
    distanceText,
    isPaused,
    elapsedSeconds,
    snapshotEpochMs,
  );
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
}) => LiveActivityContent(
  title: isPaused ? pausedTitle : recordingTitle,
  distanceText: formatDistanceKm(distanceMetres, locale: locale),
  isPaused: isPaused,
  elapsedSeconds: elapsedSeconds,
  snapshotEpochMs: nowEpochMs,
);

/// Whether [next] differs from the [last] pushed snapshot in something the
/// widget can't derive on its own — i.e. whether it is worth an update.
///
/// [LiveActivityContent.elapsedSeconds] and
/// [LiveActivityContent.snapshotEpochMs] are deliberately ignored: the widget
/// counts elapsed time natively from the last snapshot, so ticking time alone
/// never needs a push. Distance is compared by its formatted text (`X.XX km`),
/// whose resolution caps distance-driven updates at roughly one per 10 m.
/// Always true when nothing has been pushed yet ([last] is null).
bool shouldPush(LiveActivityContent? last, LiveActivityContent next) =>
    last == null ||
    last.distanceText != next.distanceText ||
    last.isPaused != next.isPaused ||
    last.title != next.title;
