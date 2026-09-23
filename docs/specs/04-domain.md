# Spec 4 — Domain / Helpers (pure Dart, TDD core)

**Status:** DONE — merged to `main`; 74 tests green, analyze clean
**Phase:** 4 of 15
**Depends on:** Spec 3 (`RideWithTrackpoints`, `Ride`, `Trackpoint`)

## Goal
Port the original app's pure logic — distance, ride stats, stats aggregation, time bounds, formatters, ride-title fallback, activity type — to **pure Dart with no Flutter imports** (except `intl` for formatting), each fully unit-tested. This is the deterministic backbone every screen relies on.

## Deliverables (all under `lib/domain/` unless noted)

### 1. `ActivityType` (`lib/domain/activity_type.dart`)
Dart enum mirroring the 7 types: `longboard, skateboard, rollerblades, rollerskates, mountainboard, scooter, other`. Each carries a stable **`id`** (the uppercase name stored in `Ride.typ`, e.g. `"LONGBOARD"`).
- `static ActivityType? fromId(String? id)` — matches by id, null if none.
- `static const ActivityType defaultType = ActivityType.longboard`.
- Label + icon are UI concerns (localized string + asset) wired in the screen phases — **not** here.

### 2. `DistanceCalculator` (`lib/domain/distance_calculator.dart`)
- `abstract interface class DistanceCalculator { double distanceBetween(double lat1, double lon1, double lat2, double lon2); }` (meters).
- `class HaversineDistanceCalculator implements DistanceCalculator` — standard Haversine, Earth radius 6371000 m.
- **Note:** the original used Android's `Location.distanceBetween` (WGS84 geodesic). Haversine differs by <0.5%, imperceptible at displayed km precision; tests assert Haversine values, not Android's. (Genuine interface seam → fakeable in tests, per CLAUDE.md.)

### 3. `RideStats` + `computeRideStats` (`lib/domain/ride_stats.dart`)
Immutable `RideStats { int durationMs; double distanceMetres; double maxSpeedKmh; double avgSpeedKmh; }` and:
```
RideStats computeRideStats(RideWithTrackpoints r, DistanceCalculator calc)
```
Replicates the original exactly:
- `durationMs` = `endTime - startTime` if both non-null, else `0`.
- `distanceMetres` = Σ haversine over consecutive trackpoints.
- `maxSpeedKmh` = `max(nonNull speeds) * 3.6`, else `0`.
- `avgSpeedKmh` = `durationMs > 0 ? (km / (durationMs/3_600_000)) : 0`.

### 4. `aggregateStats` (`lib/domain/stats_aggregation.dart`)
`WeeklyStats { double totalKm; int rideCount; double avgSpeedKmh; int totalDurationSeconds; }` + a pure aggregator reused for week/day/year (mirrors the identical HomeViewModel blocks):
```
WeeklyStats aggregateStats(List<RideWithTrackpoints> rides, DistanceCalculator calc)
```
- `totalKm` = Σ distanceMetres / 1000; `rideCount` = rides.length;
- `avgSpeedKmh` = `totalDurationMs > 0 ? totalKm / (totalDurationMs/3_600_000) : 0`;
- `totalDurationSeconds` = totalDurationMs / 1000. Empty list → all zeros.

### 5. Time bounds (`lib/domain/time_bounds.dart`)
`(int start, int end)` records, local timezone, injectable `now`:
- `weekBounds({int? nowMs})` — **Monday 00:00:00.000 → Sunday 23:59:59.999** (`daysFromMonday = (weekday - DateTime.monday) % 7`).
- `dayBounds({int? nowMs})` — today 00:00 → 23:59:59.999.
- `yearBounds({int? nowMs})` — Jan 1 00:00 → sentinel max (`9223372036854775807`, mirroring Kotlin `Long.MAX_VALUE`).

### 6. Formatters (`lib/domain/formatters.dart`, uses `intl`)
- `formatDuration(int ms)` → `H:MM:SS` (≥1h) else `MM:SS`.
- `formatElapsed(int seconds)` → same shape (live panel / notification).
- `formatRideDate(int? ms, {String? locale})` → `dd.MM.yyyy  HH:mm`, null → `"—"`.
- `formatRideTime(int? ms, {String? locale})` → `HH:mm`, null → `"—"`.
- `formatRideDayKey(int? ms)` → `yyyy-MM-dd`, null → `"0000-00-00"`.
- `formatDateLabel(String dayKey, {required String todayLabel, required String yesterdayLabel, String? locale, int? nowMs})` → today/yesterday labels, else localized `yMMMMd` (e.g. "14. Juni 2026" / "June 14, 2026" — the year is always included so history headers stay unambiguous across years); falls back to `dayKey` on parse failure. (UI passes the localized today/yesterday strings — keeps this pure.)

### 7. `rideDisplayTitle` (`lib/domain/ride_title.dart`)
`String rideDisplayTitle(Ride ride, {String? locale, int? nowMs})` → `description` if non-blank, else a FULL localized date (`yMMMMEEEEd`) of `date ?? startTime ?? now` — never empty.

> **Adjustment from the roadmap:** the *greeting selection* (random pick from the `skater_greetings` array + name interpolation) needs the localized string array, so it lives in the **Home phase (Spec 10)**, not here.

## Test-first plan (`test/domain/`)
1. `distance_calculator_test.dart` — known coordinate pairs (e.g. ~equator degree ≈ 111 km; zero distance for identical points); symmetry.
2. `ride_stats_test.dart` — empty trackpoints → 0 distance; single point → 0; null endTime → duration 0 & avg 0; maxSpeed = max speed × 3.6; avg formula on a known route.
3. `stats_aggregation_test.dart` — sums across multiple rides; avg over combined duration; empty → zeros.
4. `time_bounds_test.dart` — with a fixed `nowMs` on a known weekday: week start is the preceding Monday 00:00, end is Sunday 23:59:59.999; day bounds; year start Jan 1; Sunday edge case.
5. `formatters_test.dart` — `MM:SS` vs `H:MM:SS` boundary at 3600s; null → "—"; dayKey null → "0000-00-00"; a fixed timestamp formats as expected for `en`.
6. `date_label_test.dart` — today/yesterday/other-day branches with fixed `nowMs`.
7. `ride_title_test.dart` — non-blank description wins; blank/null → date fallback (non-empty).
8. `activity_type_test.dart` — `fromId('LONGBOARD')`, unknown → null, `defaultType`.

Write tests first (red) → implement → green.

## Acceptance criteria
- No Flutter imports in `lib/domain/` (only `dart:*` + `intl` + the Drift row types).
- `flutter analyze` clean; `flutter test` green.
- Behavior matches the original helper math exactly (duration/distance/avg/max, Monday-week bounds, format strings).
- Branch `phase/04-domain` rebased + fast-forwarded onto `main`, then deleted.

## Out of scope
ConnectivityObserver (Spec 5), greeting array (Spec 10), navigation/profile-image helpers (their UI phases), anything rendering.
