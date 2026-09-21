/// Top speed reached during a ride, mirroring the original `MapPage`
/// `LaunchedEffect`: reset to 0 when not tracking; otherwise grow (never shrink)
/// while not paused.
///
/// Lives in `domain/` because the process-lifetime tracker owns this value — it
/// used to be accumulated in the active-ride screen's widget State, where it
/// reset to 0 whenever the screen was disposed and recreated mid-ride.
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
