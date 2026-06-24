# Spec 10 — Home screen

**Status:** DONE — merged to `main`; 177 total tests green, analyze clean
**Phase:** 10 of 15
**Depends on:** Spec 3 (repos), Spec 4 (`aggregateStats`, `time_bounds`, formatters, `rideDisplayTitle`), Spec 5A (`RideTracker`), Spec 8 (shell/greetingKey), Spec 9 (`ProfileAvatar`)

## Goal
Build the Home tab: greeting header + tappable avatar, the "This week" hero card (week/day/year distances + week stats), recent rides, favorites, and the start-tracking CTA. Replaces the Spec 8 home placeholder.

> Note: Home's recent/favorite cards are **compact rows** (no map thumbnail — that's History, Spec 13).

## Data — `lib/features/home/home_providers.dart` (ports `HomeViewModel`)
- `weeklyStatsProvider` / `dailyStatsProvider` / `yearlyStatsProvider`: `StreamProvider<WeeklyStats>` = `aggregateStats(getRidesWithTrackpointsBetween(bounds), calc)` for `weekBounds`/`dayBounds`/`yearBounds` (Spec 4). Default `WeeklyStats.zero()` while loading.
- `recentRidesProvider`: `StreamProvider<List<RecentRideUi>>` from `getAllRidesWithTrackpoints` → sort by `ride.date` desc → take 2 → map to `RecentRideUi`.
- `favoriteRidesProvider`: same source, filter `isFavorite`, sort by `favoritedAt ?? date ?? 0` desc → take 2.
- `lastActivityTypeProvider` (`ActivityType`, from prefs), `isOnlineProvider` (from `ConnectivityObserver`), `isTrackingProvider` (from `RideTracker` state).
- `beginTracking(ActivityType)` — `RideTracker.setPendingActivityType(type.id)` + `saveLastActivityType`.

### `RecentRideUi` model
`{ int rideId; String title; String dateTime; double distanceKm; bool hasRoute; double? startLat; double? startLng }` — `title` via `rideDisplayTitle`, `dateTime` via `formatRideDate(ride.date)`, distance/start from `computeRideStats` + first trackpoint.

## Greeting — `lib/features/home/greeting_selector.dart` (the deferred Spec 4 piece)
Shuffled-queue strategy ported from the original: show every greeting once per cycle before reshuffling; on reshuffle, avoid a back-to-back repeat across the cycle boundary. `GreetingSelector { int next(int size) }` with an **injectable `Random`** for tests. The Home widget keeps one selector and advances it when `greetingKey` (visit count from the shell) changes. The name is rendered in `primary` (rich text), so greeting templates carry a `%s` split token (see Localization).

## Widgets — `lib/features/home/`
- `home_screen.dart` — scrollable column: `TopHeader`, `WeeklyHeroCard`, "recent rides" section, "favorites" section, start CTA pinned at bottom.
- `top_header.dart` — greeting (`titleLarge`, name in `primary`, 2-line ellipsis) + 72dp tappable `ProfileAvatar` (current photo or blank; `chipSecondary` ring). Tap opens the profile editor (wired in Spec 14 — a callback hook here).
- `weekly_hero_card.dart` — `primaryContainer` radius-14 card: a row of 3 `DistanceColumn`s (Week/Day/Year, `"X.X km"`, `titleMedium`) then a row of 3 `StatCell`s (`Ø X.X` avg speed, ride count, week duration via `formatDuration`) on `surface` radius-12 cells.
- `ride_row_card.dart` — compact row (radius-12 `surfaceContainer`): leading `Place` icon (primary if `hasRoute` else `onSurfaceVariant`), title + dateTime, optional favorite heart, distance (`"X.X km"`, primary), and a `Directions` button when `hasRoute` + start coords → opens maps at the start point.
- `empty_placeholder_card.dart` — italic centered text for empty recent/favorites.

## Start-tracking flow
- If `isTracking` → navigate to `/ride` (reopen the running ride, don't start a second).
- Else → `beginTracking(lastActivityType)`; if `isOnline` → `RideStartGate.ensureReady()` then go `/timer`; else show the offline-warning dialog (confirm → proceed).
- **`RideStartGate`** (`lib/features/home/ride_start_gate.dart`): `abstract interface class RideStartGate { Future<bool> ensureReady(); }`. The permission/GPS-settings checks are **device-specific (Part B)** — default impl returns true (straight to timer); the real impl (location permission + GPS-on check) lands with Spec 5 Part B. Interface seam → tests use a fake.
- **`NavigationLauncher`** (`lib/features/home/navigation_launcher.dart`): `abstract interface class NavigationLauncher { Future<void> launchTo(double lat, double lng, String label); }` — real impl uses `url_launcher` with a `geo:` URI (device-verified); fake in tests.

## Router/shell wiring
Replace the `_PlaceholderTab('home:…')` in `MainShell` with `HomeScreen`, passing the `greetingKey` (visit counter) the shell already tracks.

## Localization
Add: `homeDefaultName` ("Skater"), `sectionRecentRides`, `sectionRecentFavorites`, `homeEmptyNoRides`, `homeEmptyNoFavorites`, `homeWeekSection`/`homeDaySection`/`homeYearSection`, `statTempoKmh`, `statRides`, `statDurationLabel`, `homeStartTracking`, `offlineTrackingTitle`/`Body`/`Confirm`, `permissionLocationTitle`/`Body`, a11y (`navigateToStart`), and **15 greeting keys** `skaterGreeting1..15` as plain strings containing a literal `%s` token (split in code to color the name) — German per the reference. A `skaterGreetings(l10n)` helper returns the list.

## Test-first plan (`test/home/`)
1. `greeting_selector_test.dart` — every index appears once per cycle (seeded `Random`); no back-to-back across the cycle boundary; advances only when asked.
2. `home_stats_test.dart` — week/day/year providers aggregate the right rides for given bounds (in-memory Drift, fixed `now`); zero when empty.
3. `recent_favorites_test.dart` — recent = newest 2 by date; favorites = isFavorite sorted by `favoritedAt` desc, take 2; `RecentRideUi` mapping (title fallback, distance, hasRoute, start coords).
4. `home_screen_test.dart` — renders hero distances + week stats; empty placeholders when no rides/favorites; start button → `/timer` when gate allows + online (fake gate); reopens `/ride` when `isTracking`; offline → dialog.
5. `ride_row_card_test.dart` — distance + hasRoute icon tint; Directions button calls the fake `NavigationLauncher` with the start coords.

## Acceptance
- `flutter analyze` clean; full `flutter test` green.
- Home renders stats + rides; start CTA routes correctly (timer/ride/offline).
- Branch `phase/10-home` rebased + fast-forwarded onto `main`, then deleted.

## Out of scope
Timer screen (Spec 11), active-ride screen (Spec 12), History (Spec 13), profile-edit sheet (Spec 14 — Home avatar tap hook), real permission/GPS + maps-app launch (device, Part B).
