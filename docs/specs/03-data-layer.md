# Spec 3 — Data Layer (Drift + Preferences)

**Status:** DONE — merged to `main`; 45 tests green, analyze clean
**Phase:** 3 of 15
**Depends on:** Spec 1 (deps incl. Drift)

## Goal
Recreate the original Room data layer in **Drift** with the exact same schema, query set, and repository API — so later phases consume identical streams/methods. Reactive reads use Drift `Stream`s (= Room `Flow`). Preferences (was DataStore) move to a small reactive store. Clean install, **no data migration**.

## Schema (mirror Room exactly)

### `rides` table → `@DataClassName('Ride')`
| Column | Type | Notes |
|---|---|---|
| `rideId` | INTEGER PK autoincrement | |
| `description` | TEXT nullable | title |
| `typ` | TEXT nullable | ActivityType name |
| `startTime` | INTEGER nullable | epoch ms |
| `endTime` | INTEGER nullable | epoch ms |
| `date` | INTEGER nullable | = startTime, kept for parity |
| `comment` | TEXT nullable | |
| `is_favorite` | INTEGER not null default 0 | Dart `isFavorite`, SQL name `is_favorite` |
| `favorited_at` | INTEGER nullable | Dart `favoritedAt`, SQL name `favorited_at` |

### `trackpoints` table → `@DataClassName('Trackpoint')`
| Column | Type | Notes |
|---|---|---|
| `trackpointId` | INTEGER PK autoincrement | |
| `rideId` | INTEGER | FK → rides.rideId, **ON DELETE CASCADE** |
| `latitude` | REAL | |
| `longitude` | REAL | |
| `timestamp` | INTEGER | epoch ms |
| `speed` | REAL nullable | m/s from provider |

- Index on `trackpoints.rideId`.
- FK cascade enforced: enable `PRAGMA foreign_keys = ON` in the Drift `beforeOpen`.
- Schema version 1 (fresh DB; the Room 3→4→5 migrations are irrelevant to a clean install — `is_favorite`/`favorited_at` exist from the start).

### `RideWithTrackpoints` (result class)
Plain Dart class `{ Ride ride; List<Trackpoint> trackpoints }` assembled in the DAO (Drift has no `@Relation`): query the ride(s), then their trackpoints, zip together. Provided as a `Stream` for the watch variants.

## DAOs (Drift `DatabaseAccessor`s, mirroring the Room method set)

### RideDao
- `Stream<List<Ride>> getAll()`
- `Stream<List<Ride>> getAllByIds(List<int> rideIds)`
- `Stream<Ride?> getById(int rideId)`
- `Stream<List<RideWithTrackpoints>> getAllRidesWithTrackpoints()`
- `Stream<RideWithTrackpoints?> getRideWithTrackpointsById(int rideId)`
- `Stream<List<RideWithTrackpoints>> getRidesWithTrackpointsBetween(int weekStartMs, int weekEndMs)` — `startTime BETWEEN`
- `Future<int> insert(RidesCompanion ride)` — upsert semantics (`insertOnConflictUpdate`), returns rowId
- `Future<void> updateEndTime(int rideId, int endTime)`
- `Future<void> updateRideDetails(int rideId, String? description, String? comment)`
- `Future<void> updateRideType(int rideId, String? typ)`
- `Future<void> updateFavorite(int rideId, bool isFavorite, int? favoritedAt)` — writes both columns together
- `Stream<List<Ride>> getFavoriteRides()` — `is_favorite = 1 ORDER BY startTime DESC`
- `Stream<List<Ride>> getFilteredFavoriteRides({int startTime = 0, String sortBy = 'date'})`
- `Stream<List<Ride>> getFilteredRides({int startTime = 0, String sortBy = 'date', String searchQuery = ''})`
- `Future<List<int>> insertAll(List<RidesCompanion> rides)`
- `Future<void> delete(Ride ride)` / `Future<void> deleteById(int rideId)`

**Filtered-query SQL must replicate the original exactly**, including the quirk that distance/speed are NOT sortable in SQL (they come from trackpoints), so `sortBy` only special-cases `'duration'` (ASC by `endTime - startTime`) and otherwise falls back to `startTime DESC`:
```sql
WHERE (:startTime = 0 OR startTime >= :startTime)
  AND (:q = '' OR description LIKE '%'||:q||'%' OR comment LIKE '%'||:q||'%')
ORDER BY CASE WHEN :sortBy = 'duration' THEN (endTime - startTime) END ASC, startTime DESC
```

### TrackpointDao
- `Stream<List<Trackpoint>> getAll()`
- `Stream<List<Trackpoint>> getAllByIds(List<int> ids)`
- `Stream<Trackpoint?> getById(int id)`
- `Future<int> insert(TrackpointsCompanion tp)` (upsert)
- `Future<List<int>> insertAll(List<TrackpointsCompanion> list)`
- `Future<void> delete(Trackpoint tp)` / `Future<void> deleteById(int id)`

## Repositories (thin wrappers — same API as the Kotlin repos)
- `RideRepository` and `TrackpointRepository` delegate 1:1 to the DAOs.
- `RideRepository.updateFavorite(int rideId, bool isFavorite)` computes `favoritedAt = isFavorite ? clock.now() : null` — **inject a `Clock`** (default `DateTime.now`) so the timestamp is testable (the Kotlin used `System.currentTimeMillis()`).
- Exposed as Riverpod providers (`rideRepositoryProvider`, etc.); the Drift DB is a singleton provider.

## Preferences (replaces DataStore)
`PreferencesRepository` backed by `shared_preferences`, exposing reactive `Stream`s (seed current value + re-emit on write via an internal broadcast controller — adequate for our single process, mirrors `Flow`). Exact keys & defaults:

| Getter | Key | Default |
|---|---|---|
| `userName: Stream<String>` | `user_name` | `"Retrailer"` |
| `avatarIndex: Stream<int>` | `avatar_index` | `0` |
| `onboardingDone: Stream<bool>` | `onboarding_done` | `false` |
| `customPhotoPath: Stream<String?>` | `custom_photo_path` | `null` (blank treated as null) |
| `themeMode: Stream<String>` | `theme_mode` | `"system"` |
| `lastActivityType: Stream<String>` | `last_activity_type` | `"LONGBOARD"` |

Writers: `saveUserName`, `saveCustomPhotoPath`, `clearCustomPhoto`, `saveAvatarIndex`, `setOnboardingDone`, `setThemeMode`, `saveLastActivityType`.

## Test-first plan (port the Room DAO tests + add coverage)
Use an **in-memory Drift DB** (`NativeDatabase.memory()`) per test.

1. `rides_dao_test.dart` — insert→getById; getAll; upsert updates existing row; `updateEndTime`/`updateRideDetails`/`updateRideType`/`updateFavorite` mutate the right columns; `deleteById`; `getRidesWithTrackpointsBetween` includes/excludes by `startTime`.
2. `trackpoints_dao_test.dart` — insert/insertAll/getById/getAllByIds/delete; **cascade delete** (deleting a ride removes its trackpoints — the headline Room test).
3. `ride_with_trackpoints_test.dart` — assembly zips the correct trackpoints to each ride; empty-trackpoint ride yields `[]`.
4. `filtered_rides_test.dart` — search matches description OR comment; `startTime=0` returns all; `sortBy='duration'` orders by duration asc then startTime desc; favorites filter.
5. `ride_repository_test.dart` — `updateFavorite(true)` sets `favoritedAt` to the injected clock value; `updateFavorite(false)` nulls it.
6. `preferences_repository_test.dart` — defaults when unset; persisted value after write; stream re-emits on write (use `SharedPreferences.setMockInitialValues`).

Write tests first (red) → implement tables/DAOs/repos → `dart run build_runner build` → green.

## Acceptance criteria
- `dart run build_runner build` generates the Drift code cleanly.
- `flutter analyze` clean; `flutter test` green (all DAO/repo/prefs tests).
- Schema columns and FK cascade match the table above exactly.
- Branch `phase/03-data-layer` rebased + fast-forwarded onto `main`, then deleted.

## Out of scope
Stats/Haversine computation (Spec 4 consumes these streams), any UI, the GPS writer (Spec 5 writes trackpoints through `TrackpointRepository`).
