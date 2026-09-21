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
