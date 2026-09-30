# Spec 17 — Follow a saved route ("Strecke nachfahren")

**Status:** IMPLEMENTED on branch phase/17-follow-route — on-device acceptance pending (Android + iOS).
**Phase:** post-roadmap feature.
**Depends on:** Spec 5A (`RideTracker`, `LocationSource`), Spec 12 (active-ride screen), Spec 13 (ride detail dialog), Spec 16 (MapLibre `LiveMap`).

## Goal
A rider who already recorded a ride can ride it again with the old route on the map and their live GPS
position on top of it (the way Komoot shows a live dot on a planned tour). Right now they only get
the route in the detail dialog or in fullscreen. They can't see where on it they are, so they have to
memorise the route. Recording the repeat ride is **optional**: the rider chooses each time.

## Hard invariant: no effect on existing features
- `RideTracker`, the recording pipeline, the foreground service, notifications and Live Activity stay **unchanged**.
- Every new parameter (`LiveMap`, `ActiveRideScreen`) is optional and **off by default**. Without a reference route set, every screen renders and behaves exactly as today, and all existing tests stay green without edits.
- The reference route is cleared when a ride is saved, discarded or ended, and when the follow screen is left. So the next normal ride can never start with a leftover reference.

## Non-goals (this spec)
- Turn-by-turn navigation or voice prompts.
- Vibration or sound when off-route (banner only).
- GPS while backgrounded in follow-only mode (foreground only).
- The ghost rider (see **Later**). No DB/schema change in this spec.
- Reverse riding: see Spec 18.

## A. Entry flow
Two entry points, both leading into the same flow. Both entries are shown for any ride that has at least one trackpoint (rides with no trackpoints, "No route", show none). The launcher is the single place that decides followability: a reference with < 2 points, or with zero length (all points identical), is not followed — an `AlertDialog` (`followRouteUnavailableTitle` / `followRouteUnavailableBody`, one Close button) explains why instead. This check runs before the record question and before the "already recording" short-circuit, and sets no reference.
- **Ride detail dialog:** a `FilledButton.tonal` with a route icon, **"Follow route"** (`followRouteAction`), in the bottom action row, an `OverflowBar` with Follow route + the existing "Close" `TextButton` (they stack on narrow widths). It is **not** shown in the detail map's fullscreen view.
- **History card ⋮ menu:** a new **first** entry "Follow route" (same icon, same label) above Edit / Delete, shown whenever the ride has a route.
- Not added: a separate card icon (it would be easy to confuse with the existing ↱ "navigate to start" icon, which stays unchanged), and no entry on the Home "recent rides" rows (they have no menu; the path there is via the detail).

Flow:
1. The rider taps either entry point.
2. That opens a confirmation dialog **"Record this ride?"** (`followRouteRecordTitle` / `…Body`) with two actions:
   - **Record** → the normal start path (`/main/timer` → `/main/ride`) with the location permission gate as today; `routeFollowProvider.start(reference)` runs only after the gate grants, right before the countdown. While a ride is already recording, the entry goes straight to that ride with no reference.
   - **Just follow** → `routeFollowProvider.start(reference)` → `/main/follow` (new child route of `main`, next to `timer`/`ride`). The same permission gate as recording (`prepare()`: location, the notification permission and, on iOS, the background escalation).
   - Dismissing the dialog does nothing.

## B. Domain — `lib/domain/route_progress.dart` (pure, EXACT via `tdd-dart`)
Input: the reference polyline (`List<RoutePoint>`), a position, and the previous progress (nullable).
Output (immutable `RouteProgress`):
- `alongM`: distance along the reference to the projected point (Haversine, reuse `DistanceCalculator`).
- `remainingM` = total length − `alongM`.
- `offsetM`: perpendicular distance from the position to the route.
- `isOffRoute` = `offsetM > followOffRouteThresholdM` (named constant, 30 m).
- `isFinished` = within `followFinishRadiusM` (30 m) of the last point **and** `alongM ≥ 0.9 × total`.

Projection rules:
- **First fix (no previous progress):** all on-route candidates over the whole route are grouped into passes, and the **first** pass is taken, so the rider can join anywhere and a loop's start does not read as its finish.
- **While on route:** search the window [previous, previous + 500 m] (`alongM`), group the on-route candidates into passes and take the **first** pass. Progress never decreases. This keeps loops, crossings and out-and-back routes on the same road from jumping to the wrong leg.
- **Rejoin after being off-route, or an empty window:** take the pass **nearest** in along-distance to the previous progress; ties go to the pass ahead.
- `splitAt` snaps to vertices within 1e-6 m.
- Degenerate input: an empty or single-point reference yields no progress (`null`).

Test list (minimum): straight line; join mid-route; position beside the route (offset); off-route threshold boundary; loop (start ≈ finish, start must not read as finished); out-and-back on the same road (progress doesn't jump back); crossing figure-8; rejoin after off-route; finish detection; degenerate references.

## C. State — `lib/features/follow/route_follow_providers.dart`
`routeFollowProvider`: a process-lifetime `Notifier<RouteFollowState?>` (null = no reference, today's behaviour).
- `RouteFollowState` (immutable, `copyWith`): `reference` (points), `rideTitle`, `progress` (`RouteProgress?`), `recording` (bool), `lastFix`, `trail` and `locationServiceEnabled`.
- `start(reference, title, {required bool recording})`, `stop()`.
- Position source:
  - **Recording:** listens to `RideTracker`'s published location (read-only), only while `isTracking` is true — the tracker's display-only seed location never counts as progress. The tracker itself is not touched.
  - **Follow-only:** uses the same permission gate as recording (`RideRecordingController.prepare()`), then subscribes to `LocationSource` while `FollowRouteScreen` is mounted and in the foreground. Pauses on `AppLifecycleState.paused` (not on `inactive` alone) and when the screen is disposed, resumes on `resumed`; the location-service flag is seeded on resume. The `lastKnown` seed is ignored when older than `followMaxSeedAge` (2 minutes, by its capture time). A fix-stream error sets `locationServiceEnabled: false`, so the rider sees the location banner; the next accepted fix sets it back.
- Fixes with accuracy worse than 30 m are ignored. Recorder re-emits of the same fix are skipped.
- Each fix → `RouteProgress.next(...)` → new state.
- Cleared by: Home's normal start, the ride screen's exit, and the follow screen's End. It is **not** cleared on widget disposal (the follow screen's disposal only pauses the feed).

## D. Map — `LiveMap` (additive)
New optional params `reference` (`RouteTrack?`, default null), `referenceProgressM` (`double?`) and `headingTrail` (heading-up input for the follow-only screen, no line drawn), plus the constant `kReferenceRouteOpacity`.
- A `reference` GeoJSON source with halo + line layers **below** the live `route` layers, at reduced opacity (`kReferenceRouteOpacity`). It carries the same endpoint markers and direction arrows as the detail map.
- The part already ridden (`0 … referenceProgressM`) is drawn greyed (`reference-done` source, split with the same helper style as `splitRouteTail`; pure split function unit-tested).
- A reference is pushed only into sources created by the current style load (`referencePushTarget`).
- Null `reference` → no sources and layers are added (existing golden and widget tests unchanged).
- Offline with no cached style: the pre-style placeholder `RouteSketch` also draws the reference, as the detail map does.

## E. UI
All strings via ARB (en + de); colours from `AppColors`.

### E1. Recording — existing `ActiveRideScreen`
- The map gets `reference` / `referenceProgressM` from `routeFollowProvider`.
- Above `RideStatsPanel`, a slim line **"X km to go"** (`followRemaining`, formatted like the other distances) shows only while a reference is set. Before the first fix it shows the whole route's length.
- Banner **"Off route"** (`followOffRouteBanner`, reuses `RideWarningBanner`) below the existing offline/location banners. At the start, while the rider hasn't reached the route yet, it reads **"X m to the route"** / „X m bis zur Strecke" (`followDistanceToRoute`, `formatDistanceToRoute`: whole metres under 1 km, `X.XX km` from there on).
- Near the finish: no auto-stop; the rider stops the ride as always.
- The follow chrome is frozen during the exit transition.
- Without a reference: pixel-identical to today.

### E2. Follow-only — new `FollowRouteScreen` (`lib/features/follow/`)
- Builds its own header row (back arrow, title **"Follow route"**, `followRouteTitle`). It does **not** reuse `RideAppBar`, whose title and Live badge are fixed. Reuses the banners and `RideMapArea` (heading-up follow, recenter, compass).
- **Ride title** shown under the app-bar title: `ride.description` (the title set in the ride edit sheet). When it's empty the line is hidden, the same as the detail dialog does (`ride_detail_dialog.dart`).
- Bottom panel: **"X km to go"** (the route's length before the first fix) + **End** button.
- **End** asks first: dialog **"End following?"** (`followEndConfirmTitle`, Cancel / End). Back/system-back opens the same dialog.
- Not on the route yet (> 30 m): banner "X m to the route" plus a **"Navigate to start"** button in the panel → the existing `navigateTo(...)` from `navigation_chooser.dart` (external app). Both disappear once the rider is on the route.
- Finish reached: a "Finish reached" hint in the panel (`followFinished`). Ending stays manual.
- Location off: its own location-off banner (`followLocationOffBanner`, "your position can't be shown" — nothing is recorded here), the reference stays visible, progress freezes. Tapping it opens the location settings.
- Offline: the existing offline banner; the reference is drawn as in the detail map.
- The follow chrome is frozen during the exit transition.

## F. Testing
- `route_progress` and the done/remaining split → **EXACT** (`tdd-dart`).
- `routeFollowProvider` (start/stop, fixes → progress, cleared on save/discard/end, lifecycle pause) → Red-Green-Refactor with `ProviderContainer` and a fake `LocationSource`.
- Widgets (Red-Green-Refactor): detail "Follow route" button (hidden with no points, absent in fullscreen; an unfollowable route shows the explanation dialog) and history-card ⋮ entry, both → record dialog → routing; `FollowRouteScreen` (title, ride title, remaining, end confirmation, navigate-to-start visibility, finished hint); `ActiveRideScreen` with a reference (remaining line, off-route banner) **and without one (unchanged)**.
- `LiveMap` reference layers → alongside the implementation (platform view).
- On-device acceptance, Android + iOS: follow-only and recording, joining mid-route, a loop route, off-route and back, offline.

## Open follow-ups
- #48 — keep the screen on while following.
- #49 — on-device checks: reference markers, reveal cross-fade, long-route performance.

## Later — Ghost rider (not in this spec)
Compare the repeat ride against the reference in real time: a second "ghost" marker moves along the
reference at the pace recorded back then (using the reference trackpoints' `timestamp`s), plus an
ahead/behind indicator ("+0:42"). A summary comparison at save is a possible extra. This would probably need a
nullable `referenceRideId` on `Ride` (Drift migration) to link repeat rides and show "best time" per
route. Specify this in its own spec once Spec 17 is on-device verified.
