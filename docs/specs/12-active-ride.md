# Spec 12 — Active ride / map screen

**Status:** DONE — implemented test-first; 218 total tests green, analyze clean
**Phase:** 12 of 15
**Depends on:** Spec 5A (`RideTracker`, `rideTrackingStateProvider`, `ConnectivityObserver`/`isOnlineProvider`), Spec 7 (`LiveMap`, preview snapshot pipeline + `RoutePreviewCache`), Spec 9 (`ActivityType` icon/label extensions), Spec 11 (`/timer` → `/ride`)
**Branch:** `phase/12-active-ride`

---

## Goal

Port the original **`MapPage` + `MapViewModel`** behavior: the live active-ride screen the
countdown navigates into. It shows the live map with the route polyline + current-position
marker, a dark app bar with a Live/Paused badge, an offline banner, a 2×2 live-stats panel
(speed / distance / duration / top speed) with Pause-Resume and Stop, a recenter FAB, and the
three ride dialogs (confirm-stop, discard, post-ride summary). It drives the `RideTracker`
intents (start on entry, pause/resume/stop/save/discard) and, on save, triggers the
**preview-snapshot generation** for the just-recorded ride.

This replaces the `/ride` placeholder (`RidePlaceholder`) with the real screen.

---

## Scope & deferrals (read first)

The platform GPS plumbing does **not** port cleanly and is device-gated — it is **Spec 5
Part B** (deferred, per the roadmap). This spec deliberately covers only what is
unit/widget-testable today against the existing pure-Dart `RideTracker`:

**In scope (Spec 12):**
- The active-ride screen UI/chrome, embedding the existing `LiveMap` (Spec 7).
- Wiring `RideTracker` intents from the screen: `startTracking()` on entry, `pause()`/`resume()`,
  `stopTracking()`, `saveRideDetails(...)`, `discardRide()` — all already implemented in Spec 5A.
- The three dialogs (confirm-stop, discard, post-ride summary) and their callbacks.
- UI-derived **top speed** (no new tracker state, mirroring the original).
- The **navigation choreography**: start-once guard, "ride was active → go home", discard-on-dispose,
  and the back-handler "discard?" confirm.
- The **offline banner** driven by `isOnlineProvider`.
- The **preview-save wiring**: on save, render + cache the ride's preview PNG (online snapshot,
  offline flat sketch) — the "Spec 12 wiring" the `RoutePreviewCache` doc comment refers to.

**Deferred to Spec 5 Part B (device, not this spec):**
- The real location source (geolocator stream → `RideTracker.onLocationReceived`) and the
  monotonic-stamp ingestion. Without it the map shows the start fix only and no live movement —
  acceptable for the screen port; live fixes arrive with Part B and need no screen change.
- The Android foreground service + notification controls; iOS background modes.
- The **permission / GPS-settings gate** (Android's `LaunchedEffect`/permission launcher /
  `checkLocationSettings` / resolution dialog / app-settings re-check). Spec 12 starts the ride
  directly on entry behind the start-once guard; the real gate (`RideStartGate`) runs *before*
  this screen in Part B. The `permission_location_body_back` dialog is **not** ported here.

This keeps Spec 12 fully green-gated by `flutter analyze` + `flutter test`, consistent with the
project's build-green rule; Part B remains the only manually-validated phase.

---

## Architecture

```
CountdownScreen ──/ride──► ActiveRideScreen (ConsumerStatefulWidget)
                                │ watches rideTrackingStateProvider, isOnlineProvider
                                │ reads rideTrackerProvider (intents), activeRideControllerProvider
                                ▼
                          RideTracker (Spec 5A, pure Dart)  ◄── geolocator source (Spec 5B, deferred)
                                │
                                ▼ saveRideDetails → preview wiring
                          RoutePreviewCache (Spec 7) via routePreviewCacheProvider
```

### Providers (new, in `lib/features/active_ride/active_ride_providers.dart`)

- **`routePreviewCacheProvider`** — `Provider<RoutePreviewCache>`. Shared cache instance keyed to
  the app documents dir (`path_provider`), with a `PreviewRenderer` that chooses the renderer at
  call time: **online** → `renderPreviewPng(...)` via `MapTilerTileProvider` (Spec 7); **offline**
  → flat `RouteSketch` PNG (Spec 7). This is the single owner of the preview cache; History (Spec 13)
  will consume the *same* provider for its cards. (Home already renders sketch-only today; it can
  adopt this provider in Spec 13 when previews land in lists.)
- **`ActiveRideController`** (`Provider<ActiveRideController>`) — a thin, testable seam over the
  tracker + cache that owns the **save→generate-preview** sequence and the favorite toggle, so the
  widget stays declarative and the orchestration is unit-testable without pumping the screen:
  ```dart
  class ActiveRideController {
    Future<void> saveRide({String? title, String? comment, bool favorite});
    // 1) tracker.saveRideDetails(title, comment, isFavorite: favorite)
    // 2) cache.ensurePreview(lastCompletedRideId, points)   // online snapshot or offline sketch
    void discardRide();   // → tracker.discardRide()
    void stopRide();      // → tracker.stopTracking()
    void pauseOrResume(bool isPaused);
  }
  ```
  The controller reads `lastCompletedRideId` + the final `trackPoints` from the tracker's state
  snapshot at save time. It does **not** add tracker state.

> **Note on `RideTracker`:** no signature changes. `saveRideDetails`, `discardRide`,
> `stopTracking`, `pause`, `resume`, `startTracking` already exist (Spec 5A) and are used as-is,
> honoring the "never change ViewModel/business-logic signatures" rule.

---

## Screen — `lib/features/active_ride/active_ride_screen.dart` (ports `MapPage`)

A `ConsumerStatefulWidget`. Local UI state (mirroring the original `remember` vars):

| State | Purpose (from the original) |
|---|---|
| `_hasInitiatedStart` | start the ride **once** per screen session (no double rides) |
| `_rideWasActive` | becomes true once `isTracking` was seen true; gates the "go home" effect |
| `_isFollowing` | camera-follow vs free pan; controls the recenter FAB |
| `_maxSpeedKmh` | UI-derived top speed (reset when not tracking; grows while not paused) |
| `_discardOnDispose` | discard the ride in `dispose` (after the fade-out), as the original does |
| `_showConfirmStop` / `_showDiscardConfirm` / `_showSummary` | dialog visibility |

### Entry / start-once

On first build (`initState` + post-frame, or a one-shot guard) call `startTracking()` exactly once
via `_hasInitiatedStart`. (The permission/GPS gate that wraps this in the original is Spec 5B.)
Also clear the pending ride deep-link flag like the current `RidePlaceholder` does
(`pendingRideDeepLinkProvider = false`) so the router doesn't bounce back.

### Navigation choreography (faithful to `MapPage`)

- **`_rideWasActive`**: when `isTracking` is observed true, set it. When `isTracking` later flips
  false **and** no summary/confirm dialog is open, navigate home (`context.go('/')`) — this handles
  an external stop (Part B notification / task removal); the in-app Stop is excluded because it
  opens the summary dialog first.
- **Back-handler / back arrow** (`PopScope`): if tracking, show the **discard-confirm** dialog
  instead of leaving; otherwise go home. Confirm → set `_discardOnDispose = true` then go home.
- **`dispose`**: if `_discardOnDispose`, call `controller.stopRide()` + `controller.discardRide()`
  (after the route's fade-out, matching the original's `onDispose` timing).

### Layout (top→bottom), mirroring `MapPage`

1. **Dark app bar** (`AppColors.dark` surfaces, like the countdown's fixed palette): back arrow
   (`a11yBack`), the activity icon (dimmed) + title `mapActiveRideTitle`, and a **Live/Paused badge**
   on the right when tracking — a small dot + `mapLiveBadge`/`mapPausedBadge`, colored
   `LiveIndicator` (live) or a dim hint color (paused).
2. **Offline banner** — when `!isOnline`: a full-width amber bar (`AppColors` amber token — reuse
   `EditActionText`/`DeleteActionText` family already in tokens; **no new hex**) with white text
   `mapOfflineBanner`.
3. **Map area** — `LiveMap(points: state.trackPoints, current: state.location?.toRoutePoint())`,
   taking ~65 % height while tracking (else full). A **recenter FAB** (small, white, `Icons.refresh`,
   `mapRecenterCd`) overlays the bottom-start **only when `!_isFollowing`**; tapping sets following
   true. Map gestures set `_isFollowing = false` (panel-driven; `LiveMap` exposes an `onGesture`
   callback — small addition to the Spec 7 widget, no behavior change otherwise).
4. **Stats panel** (`_RideStatsPanel`, ~35 % height, only while tracking) — a centered drag handle,
   a 2×2 grid of stat cells, and the action row:
   - Cells: **Speed** (`mapStatSpeed`, `"%.1f km/h"` or `"-- km/h"`, value tinted `primary` when
     > 0), **Distance** (`mapStatDistance`, `"%.2f km"`), **Duration** (`mapStatDuration`,
     `formatElapsed`), **Top speed** (`mapStatMaxSpeed`, `"%.1f km/h"`).
   - Action row: **Pause/Resume** pill (primary-filled when paused / outlined when running →
     `pauseOrResume`) + **Stop** outlined pill → opens confirm-stop.

### Top-speed derivation (no new tracker state)

Mirror the original UI logic: when `!isTracking` reset `_maxSpeedKmh = 0`; else when `!isPaused`,
`_maxSpeedKmh = max(_maxSpeedKmh, speedKmh ?? 0)`. Computed in the screen from each state emission.
Extracted as a tiny pure helper `nextMaxSpeed(current, speed, isTracking, isPaused)` so it's
unit-testable without the widget.

---

## Dialogs — `lib/features/active_ride/ride_dialogs.dart` (ports `RideSummaryDialogs`)

Themed with the app's `AppColors` (these dialogs use theme-resolved colors in the original, unlike
the always-dark chrome). Rounded 20 dp surfaces.

- **`ConfirmStopDialog`** — title `confirmStopTitle`, body `confirmStopBody`, buttons
  `confirmStopKeep` (dismiss) / `confirmStopConfirm` (→ `stopRide()` then open summary).
- **`DiscardRideConfirmDialog`** — title `discardRideTitle`, body `discardRideBody`, buttons
  `confirmStopKeep` (dismiss) / `discardRideConfirm` (destructive, `DeleteActionText` → confirm).
- **`PostRideSummaryDialog`** — non-dismissible. Title `summaryTitle` + subtitle `summarySubtitle`;
  **Title** input (≤60 chars, single line) and **Comment** input (multi-line); a **favorite** toggle
  row (`summaryMarkFavorite` + heart icon, state held **locally in the dialog** — no new
  tracker/provider state); buttons **Skip** (`actionSkip` → save with no title, i.e. close + go home
  *without* details — matches the original `onSkip` which resets favorite and navigates, keeping the
  already-saved ride) and **Save** (`actionSave` → `controller.saveRide(title, comment, favorite)`
  then go home); and a destructive **Discard ride** text button (`summaryDiscard` →
  `controller.discardRide()` then go home).

> **Skip vs Discard semantics (faithful):** the ride row + trackpoints are persisted the moment the
> ride is stopped (Spec 5A `stopTracking`). **Skip** keeps that ride as-is (no title/comment/preview
> beyond defaults). **Discard** deletes it (CASCADE removes trackpoints). **Save** writes
> title/comment/favorite **and** generates the preview. This matches `MapViewModel`.

> **Preview on Skip:** the original generates previews lazily on first list view, so Skip needn't
> generate one now — the History card (Spec 13) will. Spec 12 only *eagerly* generates on **Save**.
> (Open question for review: eagerly generate on Skip too? Default: no, match the original.)

---

## Live map addition — `lib/map/live_map.dart`

Add an optional `onGesture` callback to `LiveMap` (fired from `MapOptions.onPointerDown` /
position-change with a user-gesture source) so the screen can flip `_isFollowing = false`. Camera
re-follow when `_isFollowing` returns true reuses the existing `didUpdateWidget` move. No change to
the polyline/marker rendering. Heading-up rotation tuning stays deferred (Spec 7 note / device).

---

## Localization — new ARB keys (`app_en.arb` + `app_de.arb`)

Mirror the Android `map_*`, `confirm_stop_*`, `discard_ride_*`, `summary_*`, `a11y_*` strings 1:1.

| Key | EN | DE |
|---|---|---|
| `mapActiveRideTitle` | `Retrail ride` | `Retrail-Fahrt` |
| `mapLiveBadge` | `Live` | `Live` |
| `mapPausedBadge` | `Paused` | `Pausiert` |
| `mapStatSpeed` | `Speed` | `Tempo` |
| `mapStatDistance` | `Distance` | `Strecke` |
| `mapStatDuration` | `Duration` | `Dauer` |
| `mapStatMaxSpeed` | `Top speed` | `Höchstgeschw.` |
| `mapStopRide` | `Stop ride` | `Fahrt beenden` |
| `mapPauseRide` | `Pause` | `Pause` |
| `mapResumeRide` | `Resume` | `Fortsetzen` |
| `mapRecenterCd` | `Re-center` | `Neu zentrieren` |
| `mapOfflineBanner` | `Offline — map tiles may not be available` | `Offline — Karte eventuell nicht verfügbar` |
| `confirmStopTitle` | `Stop ride?` | `Fahrt beenden?` |
| `confirmStopBody` | `Do you want to stop the current ride?` | `Möchtest du die aktuelle Fahrt beenden?` |
| `confirmStopKeep` | `Keep riding` | `Weiterfahren` |
| `confirmStopConfirm` | `Stop` | `Beenden` |
| `discardRideTitle` | `Discard ride?` | `Fahrt verwerfen?` |
| `discardRideBody` | `The current ride will not be saved.` | `Die aktuelle Fahrt wird nicht gespeichert.` |
| `discardRideConfirm` | `Discard` | `Verwerfen` |
| `summaryTitle` | `How was your ride?` | `Wie war die Fahrt?` |
| `summarySubtitle` | `Add a note.` | `Füge eine Notiz hinzu.` |
| `summaryMarkFavorite` | `Save as favorite` | `Als Favorit speichern` |
| `summaryTitleLabel` | `Title` | `Titel` |
| `summaryCommentLabel` | `Comment` | `Kommentar` |
| `summaryDiscard` | `Discard ride` | `Fahrt verwerfen` |
| `actionSave` | `Save` | `Speichern` |
| `a11yBack` | `Back` | `Zurück` |
| `a11yFavoriteAdd` | `Mark as favorite` | `Als Favorit markieren` |
| `a11yFavoriteRemove` | `Remove from favorites` | `Favorit entfernen` |

(`actionSkip` already exists. `permission_location_body_back` is intentionally **not** added —
the permission gate is Spec 5B.)

---

## Router/shell wiring — `lib/features/shell/app_router.dart`

Replace the `/ride` placeholder with the real screen, keeping the fade transition:

```dart
GoRoute(path: AppRoutes.ride,
    pageBuilder: (c, s) => _fade(const ActiveRideScreen(), s)),
```

No redirect changes. (`ActiveRideScreen` itself clears `pendingRideDeepLinkProvider` on entry, as
`RidePlaceholder` did.)

---

## Test-first plan

**Unit — `test/active_ride/active_ride_controller_test.dart`**
- `saveRide` calls `tracker.saveRideDetails(title, comment, favorite)` then
  `cache.ensurePreview(lastCompletedRideId, points)` (verify order + args with a fake tracker +
  fake cache).
- Offline path: when `isOnline == false`, the renderer used is the flat sketch (assert via a
  spy `PreviewRenderer`); online path uses the snapshot renderer.
- `discardRide`/`stopRide`/`pauseOrResume` delegate to the tracker.

**Unit — `test/active_ride/max_speed_test.dart`**
- `nextMaxSpeed`: resets to 0 when not tracking; grows with higher speed; ignores updates while
  paused; never decreases.

**Widget — `test/active_ride/active_ride_screen_test.dart`** (phone-sized surface like Spec 11;
override `rideTrackingStateProvider` with a `Stream.value(state)` stub, `isOnlineProvider`, and a
fake `ActiveRideController`; `LiveMap` tiles are network — they fail silently in tests, fine):
- Renders the title, the **Live** badge + stat panel when `isTracking`, and a stat grid showing the
  stubbed speed/distance/duration/top-speed strings.
- `isPaused` state shows **Paused** badge + **Resume** label.
- Offline state renders the `mapOfflineBanner`.
- Tapping **Stop** opens confirm-stop; confirming calls the controller's `stopRide` and opens the
  summary dialog.
- Summary **Save** calls `saveRide(...)` with the entered title/comment/favorite and navigates home.
- Summary **Discard** calls `discardRide` and navigates home.
- Recenter FAB hidden while following; appears after a simulated gesture (`onGesture`), and tapping
  re-follows (FAB hides again).

**Widget — `test/active_ride/ride_dialogs_test.dart`**
- ConfirmStop / Discard / Summary render their strings and fire the right callbacks; summary title
  input caps at 60 chars; favorite toggle flips the heart + a11y label.

All gated by `flutter analyze` clean + full suite green before the phase is done.

---

## Acceptance

- `/ride` shows the real active-ride screen; entering it starts the ride once (`startTracking`).
- Live badge, offline banner, 2×2 stats (with UI-derived top speed), pause/resume, and the recenter
  FAB behave as in the original.
- Stop → confirm → summary → Save persists details and **generates the preview PNG** (online snapshot
  or offline flat sketch); Discard deletes the ride; Skip keeps it untitled.
- Back/discard choreography and discard-on-dispose match the original.
- `flutter analyze` clean; full suite green.

---

## Out of scope (later / deferred)

- Real geolocator location source + foreground service + iOS background modes → **Spec 5 Part B**.
- Permission / GPS-settings gate (`RideStartGate`) and its dialog → **Spec 5 Part B**.
- iOS Live Activity lock-screen controls → **Spec 6**.
- Heading-up rotation/follow tuning, FMTC tile caching → **Spec 7 / device work**. The
  recenter FAB currently only flips `_isFollowing`; actually re-centering the camera lands with
  the follow tuning (no live GPS in Spec 12, so it's invisible today).
- History list embedding the preview cards → **Spec 13** (consumes `routePreviewCacheProvider`).
