---
title: "Elevation ignores platform placeholder altitudes and the climb test allows 5 m, not 3 m"
author: Valiju
date: 2026-11-10
branch: feature/elevation
id: l-3af7c688
scope: repo
status: active
src: agent
touches:
  - test/domain/elevation_test.dart
---

## Decided
An altitude is dropped when it is not finite, when the vertical accuracy is negative (iOS marks an invalid altitude this way), when it is worse than 25 m, or when it is exactly 0 with unknown accuracy (Android reports 0.0 when it has no altitude). Unknown accuracy otherwise counts as valid.
The "steady climb" scenario allows 5 m of deviation. The 5-sample median lags by 2 m and the 3 m hysteresis holds back up to just under 3 m, so 100 m of climbing reads as about 96 m; the original 3 m tolerance could never pass.

## Tried and ruled out
Averaging the two middle samples for an even window: the example 100, 110, 100 then gives 5 m instead of 10 m. The upper median is used.

## Watch out
Trackpoints reach the elevation sum through a join without ORDER BY (same assumption as the ride stats); it relies on insertion order.

In the code: LocationFix.recordedAltitude, ElevationAccumulator, the "steady climb" test in test/domain/elevation_test.dart.
