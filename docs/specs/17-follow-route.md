# Spec 17 — Follow a saved route ("Strecke nachfahren")

**Status:** DRAFT — awaiting review.
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
- Riding a route in reverse as a supported mode (progress assumes the recorded direction).

## A. Entry flow
Two entry points, both shown only when the ride has ≥ 2 points and both leading into the same flow:
- **Ride detail dialog:** a `FilledButton.tonal` with a route icon, **"Follow route"** (`followRouteAction`), in the bottom action row left of the existing "Close" `TextButton`. It is **not** shown in the detail map's fullscreen view.
- **History card ⋮ menu:** a new **first** entry "Follow route" (same icon, same label) above Edit / Delete.
- Not added: a separate card icon (it would be easy to confuse with the existing ↱ "navigate to start" icon, which stays unchanged), and no entry on the Home "recent rides" rows (they have no menu; the path there is via the detail).

Flow:
1. The rider taps either entry point.
2. That opens a confirmation dialog **"Record this ride?"** (`followRouteRecordTitle` / `…Body`) with two actions:
   - **Record** → `routeFollowProvider.start(reference)` → then the normal start path (`/main/timer` → `/main/ride`). Location permission gate as today.
   - **Just follow** → `routeFollowProvider.start(reference)` → `/main/follow` (new child route of `main`, next to `timer`/`ride`). Location permission gate as today (foreground permission is enough).
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
- **First fix (no previous progress):** project onto the nearest segment of the whole route, so the rider can join anywhere.
- **Later fixes:** search only a forward window starting a little behind the previous `alongM` (e.g. −50 m … +500 m of route length). This keeps loops, crossings and out-and-back routes on the same road from jumping to the wrong leg.
- **Rejoin after being off-route:** while off-route, fall back to a whole-route search. The first on-route fix re-anchors the window.
- Degenerate input: an empty or single-point reference yields no progress (`null`).

Test list (minimum): straight line; join mid-route; position beside the route (offset); off-route threshold boundary; loop (start ≈ finish, start must not read as finished); out-and-back on the same road (progress doesn't jump back); crossing figure-8; rejoin after off-route; finish detection; degenerate references.

## C. State — `lib/features/follow/route_follow_providers.dart`
`routeFollowProvider`: a process-lifetime `Notifier<RouteFollowState?>` (null = no reference, today's behaviour).
- `RouteFollowState` (immutable, `copyWith`): `reference` (points), `rideTitle`, `progress` (`RouteProgress?`), `recording` (bool).
- `start(reference, title, {required bool recording})`, `stop()`.
- Position source:
  - **Recording:** listens to `RideTracker`'s published location (read-only). The tracker itself is not touched.
  - **Follow-only:** subscribes to `LocationSource` while `FollowRouteScreen` is mounted and in the foreground. Pauses on `AppLifecycleState.paused`, resumes on `resumed`.
- Each fix → `RouteProgress.next(...)` → new state.
- Cleared by: save / discard in `ActiveRideController` (a listener in the follow feature, **not** code inside the tracker), "End" in the follow screen, and disposal of the follow route.

## D. Map — `LiveMap` (additive)
New optional param `referenceRoute` (`List<RoutePoint>?`, default null) plus `referenceProgressM` (`double?`).
- A `reference` GeoJSON source with halo + line layers **below** the live `route` layers, at reduced opacity (`followReferenceOpacity` token). It carries the same endpoint markers and direction arrows as the detail map.
- The part already ridden (`0 … referenceProgressM`) is drawn greyed (`reference-done` source, split with the same helper style as `splitRouteTail`; pure split function unit-tested).
- Null `referenceRoute` → no sources and layers are added (existing golden and widget tests unchanged).
- Offline with no cached style: the pre-style placeholder `RouteSketch` also draws the reference, as the detail map does.

## E. UI
All strings via ARB (en + de); colours from `AppColors`.

### E1. Recording — existing `ActiveRideScreen`
- The map gets `referenceRoute` / `referenceProgressM` from `routeFollowProvider`.
- Above `RideStatsPanel`, a slim line **"X km to go"** (`followRemaining`, formatted like the other distances) shows only while a reference is set.
- Banner **"Off route"** (`followOffRouteBanner`, reuses `RideWarningBanner`) below the existing offline/location banners. At the start, while the rider hasn't reached the route yet, it reads **"X m to the route"** (`followDistanceToRoute`).
- Near the finish: no auto-stop; the rider stops the ride as always.
- Without a reference: pixel-identical to today.

### E2. Follow-only — new `FollowRouteScreen` (`lib/features/follow/`)
- Reuses `RideAppBar` (title **"Follow route"**, `followRouteTitle`), the banners, and `RideMapArea` (heading-up follow, recenter, compass).
- **Ride title** shown under the app-bar title: `ride.description` (the title set in the ride edit sheet). When it's empty the line is hidden, the same as the detail dialog does (`ride_detail_dialog.dart`).
- Bottom panel: **"X km to go"** + **End** button.
- **End** asks first: dialog **"End following?"** (`followEndConfirmTitle`, Cancel / End). Back/system-back opens the same dialog.
- Not on the route yet (> 30 m): banner "X m to the route" plus a **"Navigate to start"** button in the panel → the existing `navigateTo(...)` from `navigation_chooser.dart` (external app). Both disappear once the rider is on the route.
- Finish reached: a "Finish reached" hint in the panel (`followFinished`). Ending stays manual.
- Location off: the existing location-off banner, the reference stays visible, progress freezes.
- Offline: the existing offline banner; the reference is drawn as in the detail map.

## F. Testing
- `route_progress` and the done/remaining split → **EXACT** (`tdd-dart`).
- `routeFollowProvider` (start/stop, fixes → progress, cleared on save/discard/end, lifecycle pause) → Red-Green-Refactor with `ProviderContainer` and a fake `LocationSource`.
- Widgets (Red-Green-Refactor): detail "Follow route" button (hidden < 2 points, absent in fullscreen) and history-card ⋮ entry, both → record dialog → routing; `FollowRouteScreen` (title, ride title, remaining, end confirmation, navigate-to-start visibility, finished hint); `ActiveRideScreen` with a reference (remaining line, off-route banner) **and without one (unchanged)**.
- `LiveMap` reference layers → alongside the implementation (platform view).
- On-device acceptance, Android + iOS: follow-only and recording, joining mid-route, a loop route, off-route and back, offline.

## Later — Ghost rider (not in this spec)
Compare the repeat ride against the reference in real time: a second "ghost" marker moves along the
reference at the pace recorded back then (using the reference trackpoints' `timestamp`s), plus an
ahead/behind indicator ("+0:42"). A summary comparison at save is a possible extra. This would probably need a
nullable `referenceRideId` on `Ride` (Drift migration) to link repeat rides and show "best time" per
route. Specify this in its own spec once Spec 17 is on-device verified.
