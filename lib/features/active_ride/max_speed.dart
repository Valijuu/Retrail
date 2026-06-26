/// UI-derived top speed, mirroring the original `MapPage` `LaunchedEffect`:
/// reset to 0 when not tracking; otherwise grow (never shrink) while not paused.
/// Kept as a pure function so it can be unit-tested without the widget.
double nextMaxSpeed({
  required double current,
  required double? speedKmh,
  required bool isTracking,
  required bool isPaused,
}) {
  if (!isTracking) return 0;
  if (isPaused) return current;
  final s = speedKmh ?? 0;
  return s > current ? s : current;
}

/// Whether an external stop (e.g. notification / task removal in Spec 5B) should
/// bounce the screen home. The in-app Stop is excluded via [anyDialogOpen],
/// because it shows the confirm/summary dialog first. Mirrors `MapPage`'s
/// `rideWasActive` navigation effect.
bool shouldNavigateHomeOnStop({
  required bool rideWasActive,
  required bool isTracking,
  required bool anyDialogOpen,
}) =>
    rideWasActive && !isTracking && !anyDialogOpen;
