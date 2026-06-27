# Spec 5B — GPS platform plumbing (location source, permissions, background service)

**Status:** IMPLEMENTED (headless) — 280 tests green, analyze clean, debug APK builds.
**Awaiting on-device verification (Android + iOS) before merge** — a green headless gate proves the
wiring compiles, NOT that GPS records screen-off or the controls work. Do not merge until the
device acceptance below passes on both platforms.
**Phase:** 5 of 15, Part B (Part A done & merged: `RideTracker` + 9-stage filter + `ConnectivityObserver`)
**Depends on:** Spec 5A (`RideTracker`, `LocationFix`, `onLocationReceived`), Spec 8 (deep-link
`pendingRideDeepLinkProvider`, router), Spec 12 (active-ride screen + `ActiveRideController`),
Spec 15 (manifest permissions + iOS background-mode/usage-string declarations already in place)
**Branch:** `phase/05b-gps-platform`

---

## The bug this closes

Pressing **Start** today inserts a ride and ticks the duration timer, but **nothing requests
permission, nothing feeds GPS, and no notification shows** — because the location *source* was
deferred from Part A. `geolocator` appears in `lib/` only in comments; `RideTracker.onLocationReceived`
is never called in production. This spec wires the platform layer that drives the already-tested
pure-Dart core: permission flow → live fixes → the location dot + recording → the foreground-service
notification → screen-off background recording.

The integration point exists and is marked: `active_ride_screen.dart` `initState` calls
`_controller.startRide()` in a post-frame callback, with the comment *"The permission / GPS-settings
gate that wraps this in the original is Spec 5 Part B."* That call site is what this spec wraps.

---

## Architecture decision (the crux) — main-isolate tracking, service for keep-alive

`flutter_foreground_task` v9 runs its task callback in a **separate isolate**, which cannot share the
process-singleton `RideTracker` the UI reads. The original Android app shares one `RideTracker`
(Hilt singleton) across the service and the UI. To preserve that model and keep the 40+ tested
`RideTracker` behaviors as the single source of truth:

- **The `geolocator` position stream and `RideTracker` live in the main (UI) isolate.** A
  foreground service of type `location` keeps the process alive + unthrottled with the screen off,
  so the main-isolate stream keeps delivering fixes. This is the standard
  `flutter_foreground_task` + `geolocator` recipe.
- **`flutter_foreground_task` is used for keep-alive + the ongoing notification + relaying its
  action-button taps** (Pause/Resume/Stop) back to the main isolate, where they call
  `ActiveRideController`. We do **not** move tracking logic into the task isolate.

This is a recommendation, not a user decision; called out here because it shapes B2/B3.

---

## Staging

- **B1 — foreground / in-use (verifiable immediately on a device):** permission gate +
  `GeolocatorLocationSource` → `RideTracker`. Gives the **location dot + recording while the app is
  open** — the most visible part of the reported bug — and the permission prompt.
- **B2 — Android background + notification:** `flutter_foreground_task` service, ongoing
  notification (live elapsed·distance) with Pause/Resume/Stop + tap-deep-link, task-removal finalize.
- **B3 — iOS background:** "Always" authorization, `allowsBackgroundLocationUpdates`, ongoing local
  notification (lock-screen controls are the Live Activity in **Spec 6**).

B1 lands first and is independently testable on-device; B2/B3 follow.

---

## B1. Location source + permission gate

### `LocationSource` seam — `lib/tracking/location_source.dart`
```dart
abstract interface class LocationSource {
  Stream<LocationFix> get fixes;       // high-accuracy, ~1 s cadence
  Future<LocationFix?> lastKnown();    // seed an immediate marker (no blank map)
}
```
`GeolocatorLocationSource` impl: `Geolocator.getPositionStream(LocationSettings(accuracy: high,
distanceFilter: 0))` mapped to `LocationFix`. The original used `PRIORITY_HIGH_ACCURACY`, 1 s
interval / 0.5 s fastest — mirror with `AndroidSettings(intervalDuration: 1s)` /
`AppleSettings(activityType: otherNavigation)`.

> **CRITICAL (carried from 5A, project memory):** `LocationFix.elapsedRealtimeNanos` MUST be the
> fix's **real capture time** — `Position.timestamp.microsecondsSinceEpoch * 1000` — NOT a clock
> read at ingestion. Synthesizing it makes `now − fixTime ≈ 0` for every fix, turning the stage-0
> freshness filter into a no-op and reviving the stale-cached-fix "teleport". The production default
> `nowNanos` reads the same wall-clock source so the comparison is like-for-like.

### Permission gate — `lib/tracking/location_permission.dart`
A thin, testable wrapper over `geolocator` permission + `Geolocator.isLocationServiceEnabled()`,
mirroring the original `MapPage` flow:
1. **Location services on?** (`isLocationServiceEnabled`) — if off, surface the "turn on location"
   prompt (`Geolocator.openLocationSettings()`); the original launched the `ResolvableApiException`
   resolution dialog.
2. **Permission:** `checkPermission` → if `denied`, `requestPermission`. `whileInUse` or `always`
   → proceed. `deniedForever` → show the rationale dialog with an "open app settings"
   (`Geolocator.openAppSettings()`) path (mirrors the original `showPermissionDialog`).
3. **Android 13+ notifications:** request `POST_NOTIFICATIONS` (via `flutter_foreground_task`'s
   `requestNotificationPermission()` in B2) so the recording notification can show — without it,
   "no alerts," exactly as reported.

A pure `PermissionGateDecision` function maps `(serviceEnabled, permission)` → one of
`proceed | requestPermission | openLocationSettings | showRationale`, so the branching is unit-tested
without the platform.

### Wiring — where it hooks in
- New `RideRecordingController` (or fold into `ActiveRideController`) owns: start the
  `LocationSource` subscription feeding `tracker.onLocationReceived`, seed `lastKnown()`, and cancel
  on stop/discard. `startRide()` becomes: **gate permission → if granted, start source + (B2) the
  foreground service → `tracker.startTracking()`**; if not granted, don't start (show the gate UI).
- `active_ride_screen.dart` `initState` replaces the bare `_controller.startRide()` with the
  permission-gated start; denial routes back / shows the rationale dialog rather than a silent
  no-GPS ride.
- `rideTrackingStateProvider` already exposes `location`; the live map already renders the dot from
  `current` — so once fixes flow, the dot appears with no map change.

---

## B2. Android foreground service + notification — `flutter_foreground_task`

- Configure a `location`-typed foreground service; start it in `startRide()` after the gate, stop it
  on stop/discard. Channel: `IMPORTANCE_DEFAULT`, **silent** (no sound/vibration), `onlyAlertOnce`
  — exactly the original's `ride_tracking_v2` channel rationale (a LOW channel hides the control).
- **Ongoing notification** shows `formatElapsed(elapsed) · X.XX km` (reuse the Spec 4 formatter),
  title = recording / paused variant, updated as state changes. Actions: **Pause/Resume** (toggle)
  + **Stop**; tapping the body deep-links into the active ride (set `pendingRideDeepLinkProvider`
  → router opens `/ride`, the Spec 8 infra).
- Action taps relay to the main isolate → `ActiveRideController.pauseOrResume()/stopRide()`. Stop
  finalizes the ride (idempotent with the in-app Stop).
- **Task removal / swipe-away:** finalize the active ride (so it lands in history with an end time)
  and tear down — mirrors the original `onTaskRemoved`, preventing the next start from silently
  re-attaching to a stale `isTracking == true` ride.

## B3. iOS background

- Request **Always** authorization for screen-off recording — Android's location FGS covers
  background, but iOS has none, so `whileInUse` alone stops recording at lock. Implemented as a
  best-effort escalation (`ensureBackgroundPermission`): after the gate proceeds, iOS re-requests to
  upgrade `whileInUse → Always` (Android no-op). Set `allowsBackgroundLocationUpdates`
  + `pausesLocationUpdatesAutomatically = false` via `AppleSettings`. `UIBackgroundModes: location`,
  the usage strings, and `NSSupportsLiveActivities` are already declared (Spec 15); add `de` to the
  Xcode known regions so `InfoPlist.strings` loads (logged in Spec 15B).
- iOS shows an ongoing **local notification** while recording; lock-screen Pause/Resume/Stop is the
  **Live Activity (Spec 6)**, out of scope here.

---

## Manifest / config (mostly already in place)

Android permissions (INTERNET, ACCESS_FINE/COARSE_LOCATION, FOREGROUND_SERVICE(+_LOCATION),
POST_NOTIFICATIONS) were added in Spec 15. `flutter_foreground_task` contributes its own
`<service>` entry; verify it declares `foregroundServiceType="location"`. No new Dart deps —
`geolocator` and `flutter_foreground_task` are already in `pubspec.yaml`.

---

## Localization — new ARB keys (mirror the original `notif_*` / `permission_*`)

| Key | EN | DE |
|---|---|---|
| `notifRecordingTitle` | `Recording ride` | `Fahrt wird aufgezeichnet` |
| `notifRecordingPausedTitle` | `Ride paused` | `Fahrt pausiert` |
| `notifActionPause` | `Pause` | `Pause` |
| `notifActionResume` | `Resume` | `Fortsetzen` |
| `notifActionStop` | `Stop` | `Beenden` |
| `notifChannelName` | `Ride tracking` | `Fahrtenaufzeichnung` |
| `permissionLocationTitle` | `Location needed` | `Standort erforderlich` |
| `permissionLocationBody` | `Retrail needs location access to record your route.` | `Retrail benötigt Standortzugriff, um deine Strecke aufzuzeichnen.` |
| `permissionOpenSettings` | `Open settings` | `Einstellungen öffnen` |
| `permissionEnableLocation` | `Turn on location to start recording.` | `Aktiviere den Standort, um die Aufzeichnung zu starten.` |

---

## Test-first plan

**Headless (the automated green-gate for this spec):**
- `location_source_test.dart` — `GeolocatorLocationSource` maps a fake `Position` stream to
  `LocationFix`, asserting **`elapsedRealtimeNanos == Position.timestamp` in ns** (the critical
  correctness point), accuracy/speed/hasSpeed passthrough.
- `location_permission_test.dart` — the pure `PermissionGateDecision` over every
  `(serviceEnabled, LocationPermission)` combination → expected action.
- `ride_recording_controller_test.dart` — a **fake `LocationSource`** emitting a synthetic track
  through the real `RideTracker` (in-memory Drift): fixes record trackpoints + advance live state;
  permission-denied → no start, no ride; stop/discard cancels the subscription.
- Notification-action relay: an action event (`pause`/`resume`/`stop`) → the matching
  `ActiveRideController` intent (fake controller spy).

**Device-gated (manual, both OSes — no automated gate, matches Part A's stance):** real permission
prompts; the dot appears + records with the app open; screen-off background recording continues;
the notification shows with working Pause/Resume/Stop + body deep-link; task-swipe finalizes; iOS
"Always" + background; offline/flight-mode still records and draws the route.

All headless tests + existing suite green under `flutter analyze` + `flutter test` before merge;
device acceptance verified on hardware (as in Part A).

---

## Acceptance

- Pressing Start prompts for location (and notifications on Android 13+); granting shows the live
  **location dot** and records distance/speed; denying shows the rationale, not a silent dead ride.
- Recording continues with the screen off; the ongoing notification shows live elapsed·distance with
  working Pause/Resume/Stop and a tap-to-open deep-link (Android).
- iOS records in the background with "Always" granted (lock-screen controls deferred to Spec 6).
- Headless suite green; device acceptance passes on Android + iOS.

---

## Out of scope (deferred)

- iOS **Live Activity / Dynamic Island** lock-screen controls → **Spec 6**.
- On-device end-to-end release run → **Spec 15 Part B**.
