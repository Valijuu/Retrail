/// Live speed from two fixes when the GPS provider reports none (iOS: -1 while
/// standing still) — display only; recording has its own filter.
library;

import 'dart:math' as math;

/// 1 m/s = 3600 s/h ÷ 1000 m/km = 3.6 km/h.
const double _kmhPerMetrePerSecond = 3.6;

/// Speed in km/h implied by two consecutive fixes [distanceMetres] apart and
/// [elapsedSeconds] between them, or null when the pair can't be trusted.
///
/// Rules, in order:
/// - `elapsedSeconds <= 0` → null: duplicate or out-of-order timestamps give
///   no meaningful rate (and would divide by zero).
/// - either accuracy `> maxAccuracyM` → null: a coarse fix (Wi-Fi/cell
///   fallback indoors) can sit 100+ m off, so any speed from it is noise.
/// - distance `<= max(accuracyA, accuracyB)` → 0.0: the movement fits inside
///   the fixes' own error radius, so it is indistinguishable from standing
///   still — this is what stops ~699 km/h readings while stationary.
/// - implied speed `> maxSpeedMs` → null: a physically impossible jump for a
///   ride means one fix is wrong, not that the rider is fast.
/// - otherwise the implied m/s converted to km/h.
///
/// The thresholds come from the caller (the tracker's GPS filter) so domain
/// logic stays free of tracking-layer imports.
double? fallbackSpeedKmh({
  required double distanceMetres,
  required double elapsedSeconds,
  required double accuracyA,
  required double accuracyB,
  required double maxAccuracyM,
  required double maxSpeedMs,
}) {
  if (elapsedSeconds <= 0 ||
      accuracyA > maxAccuracyM ||
      accuracyB > maxAccuracyM) {
    return null;
  }
  if (distanceMetres <= math.max(accuracyA, accuracyB)) return 0.0;
  final speedMs = distanceMetres / elapsedSeconds;
  if (speedMs > maxSpeedMs) return null;
  return speedMs * _kmhPerMetrePerSecond;
}
