import 'gps_fix_filter.dart';
import 'location_fix.dart';

/// The GPS status the pre-ride countdown shows (#69), so the rider knows
/// whether the first metres will be recorded or swallowed while GPS warms up.
///
/// Display only: recording still runs every fix through [GpsFixFilter] on its
/// own, whatever this says.
enum GpsSignal {
  /// Location services are switched off — no fix will arrive until the rider
  /// turns them back on.
  off,

  /// Services are on, but there is no fix yet that the recording filter would
  /// accept: none at all, a stale cached one, or one that is too vague.
  searching,

  /// The latest fix passes the filter's freshness and accuracy checks, so
  /// recording can start right away.
  ready,
}

/// Rates [fix] (the latest known position, if any) at [nowNanos] on the same
/// clock as [LocationFix.elapsedRealtimeNanos] (#69).
///
/// Reuses [GpsFixFilter]'s thresholds instead of its own, so "ready" means
/// exactly "the recorder would take this fix".
GpsSignal gpsSignal({
  required LocationFix? fix,
  required bool serviceEnabled,
  required int nowNanos,
}) {
  if (!serviceEnabled) return GpsSignal.off;
  return fix != null && _isRecordable(fix, nowNanos)
      ? GpsSignal.ready
      : GpsSignal.searching;
}

/// The filter's step 0 (freshness) and accuracy check — the parts that depend
/// on the fix alone, not on a previously recorded point.
bool _isRecordable(LocationFix fix, int nowNanos) =>
    GpsFixFilter.isFresh(fix, nowNanos) &&
    fix.accuracy <= GpsFixFilter.accuracyThresholdM;
