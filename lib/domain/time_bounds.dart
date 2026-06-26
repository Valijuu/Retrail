/// Inclusive `(start, end)` epoch-millisecond bounds, computed in the device's
/// local timezone. `now` is injectable for deterministic tests.
typedef Bounds = (int start, int end);

/// Mirrors `Long.MAX_VALUE` used by the original year bound.
const int maxBoundMs = 9223372036854775807;

int _nowMs(int? nowMs) => nowMs ?? DateTime.now().millisecondsSinceEpoch;

/// Today 00:00:00.000 → 23:59:59.999 (local).
Bounds dayBounds({int? nowMs}) {
  final now = DateTime.fromMillisecondsSinceEpoch(_nowMs(nowMs));
  final start = DateTime(now.year, now.month, now.day);
  final endExclusive = DateTime(now.year, now.month, now.day + 1);
  return (start.millisecondsSinceEpoch, endExclusive.millisecondsSinceEpoch - 1);
}

/// Monday 00:00:00.000 → Sunday 23:59:59.999 of the current week (local).
Bounds weekBounds({int? nowMs}) {
  final now = DateTime.fromMillisecondsSinceEpoch(_nowMs(nowMs));
  // DateTime.weekday: Mon=1 … Sun=7, so Mon→0 … Sun→6.
  final daysFromMonday = (now.weekday - DateTime.monday) % 7;
  final start = DateTime(now.year, now.month, now.day - daysFromMonday);
  final endExclusive =
      DateTime(start.year, start.month, start.day + 7);
  return (start.millisecondsSinceEpoch, endExclusive.millisecondsSinceEpoch - 1);
}

/// First of the current month 00:00:00.000 → last day 23:59:59.999 (local).
Bounds monthBounds({int? nowMs}) {
  final now = DateTime.fromMillisecondsSinceEpoch(_nowMs(nowMs));
  final start = DateTime(now.year, now.month, 1);
  final endExclusive = DateTime(now.year, now.month + 1, 1);
  return (start.millisecondsSinceEpoch, endExclusive.millisecondsSinceEpoch - 1);
}

/// Jan 1 00:00:00.000 of the current year → [maxBoundMs] (local start).
Bounds yearBounds({int? nowMs}) {
  final now = DateTime.fromMillisecondsSinceEpoch(_nowMs(nowMs));
  final start = DateTime(now.year, 1, 1);
  return (start.millisecondsSinceEpoch, maxBoundMs);
}
