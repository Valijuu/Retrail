# Spec 5 — GPS Tracking Engine (HIGH RISK)

**Status:** Part A DONE — merged to `main` (39 ported RideTracker tests + 6 connectivity tests green, analyze clean). Part B (platform plumbing) pending the device spike.
**Phase:** 5 of 15
**Depends on:** Spec 3 (repositories), Spec 4 (`DistanceCalculator`, `ActivityType`)

## Goal
Port the original `RideTracker` — the process-lifetime recording state machine and its **9-stage GPS filter** — to pure Dart with all **39 tests** carried over, plus the VPN-aware `ConnectivityObserver`. Then wire the **platform location/foreground plumbing** (the part that does NOT port cleanly), de-risked by an early spike. iOS Live Activity lock-screen controls are **Spec 6**.

This is the riskiest phase, so it's split: **Part A** (pure Dart, fully unit-tested, the bulk of the value) and **Part B** (platform integration, device-validated).

---

## Part A — Pure Dart core (test-first, no Flutter plumbing)

### A1. `LocationFix` (`lib/tracking/location_fix.dart`)
Platform-agnostic value type the filter consumes (decouples from geolocator):
`{ double latitude, longitude, accuracy; bool hasSpeed; double speed; int elapsedRealtimeNanos }` — `elapsedRealtimeNanos` is a **monotonic** clock reading (geolocator gives wall-clock; we synthesize a monotonic stamp at ingestion, see Part B).

### A2. `RideTracker` (`lib/tracking/ride_tracker.dart`)
Plain Dart singleton (not a widget/Notifier) holding live state + the recording pipeline. Exposes one immutable state object via a `ValueNotifier<RideTrackingState>` (UI reads it through a Riverpod provider):
```
RideTrackingState {
  LocationFix? location; bool isTracking; List<({double lat, double lng})> trackPoints;
  double distanceMetres; double? speedKmh; int elapsedSeconds; bool isPaused;
  ActivityType? activityType;
}
```
> **Adjustment:** the original exposed 8 separate `StateFlow`s; we consolidate into one immutable state (same data, selected per-field by the UI). Ported tests assert `tracker.state.<field>`.

Constructor injects `RideRepository`, `TrackpointRepository`, `DistanceCalculator`, and an overridable `nowNanos` clock (default monotonic). Methods mirror the original exactly:
- `setPendingActivityType(String? id)`
- `startTracking()` — sets tracking/activityType synchronously, then async-inserts the `Ride` (typ = pending, startTime/date = now) → `activeRideId`; resets trackPoints/distance/speed/elapsed; starts the 1s elapsed timer.
- `stopTracking()` — records `lastCompletedRideId`, cancels timer, sets endTime = now, clears tracking/paused.
- `pause()` / `resume()` — freeze/continue timer; `resume` clears `lastRecordedLocation` so the break gap isn't counted as distance. No-ops per the guards.
- `saveRideDetails(description, comment, {isFavorite})` — updates the `lastCompletedRideId`.
- `discardRide()` — deletes `lastCompletedRideId` (CASCADE removes trackpoints), resets live state.
- `onLocationReceived(LocationFix)` — the filter pipeline below.

### A3. The 9-stage filter (`onLocationReceived`) — port verbatim
Constants (unchanged): `ACCURACY_THRESHOLD_M=35`, `MIN_DISTANCE_M=8.0`, `MIN_SPEED_MS=0.5`, `STATIONARY_SPEED_MS=0.8`, `MAX_FIX_AGE_NANOS=5_000_000_000`, `MAX_SPEED_MS=50.0`.
0. **Freshness:** drop if `nowNanos() - fix.elapsedRealtimeNanos > MAX_FIX_AGE_NANOS` (before any state update — kills the stale cached-fix "teleport").
1. Always update live `location` + `speedKmh` (`computeSpeedKmh`: provider speed×3.6, else displacement/time fallback).
2. If paused → return (live marker still updated).
3. If no `activeRideId` → return.
4. **Accuracy:** drop if `accuracy > 35`.
5. **Stationary guard:** if `hasSpeed && speed < 0.8` → return.
6. **Outlier:** if `distance/elapsedS > 50` → return (keep last good point).
7. **Displacement:** require `distance ≥ max(8, last.accuracy, fix.accuracy)`.
8. **Implied speed:** if `distance/elapsedS < 0.5` → return.
9. Passed → accumulate distance, append trackPoint, async-insert `Trackpoint` (speed = provider speed or null).

### A4. `ConnectivityObserver` (`lib/core/connectivity/connectivity_observer.dart`)
Reactive `Stream<bool>`/`ValueNotifier<bool>` `isOnline`. **VPN-aware:** never trusts the OS "validated" flag (NordVPN fakes it — see project memory). Strategy ported exactly:
- Fast path: no active network / no INTERNET capability → offline.
- Else **active HTTP probe** to `https://clients3.google.com/generate_204` (2.5s timeout, no redirects/cache) → online iff status 200–399.
- Re-evaluate on connectivity-change events (`connectivity_plus`) **and** a 10s poll, only while observed.
- Injects an `http.Client` + a connectivity event source so it's unit-testable.

### Part A test-first plan (`test/tracking/`, `test/core/`)
**Port all 39 `RideTrackerTest` cases** using `mocktail` (repos + a fake `DistanceCalculator` returning 100 m) and `fake_async`/`FakeAsync` for the 1s timer (replacing Kotlin's `advanceTimeBy`), with an injected `nowNanos` (default `0`). Grouped:
- **Lifecycle (4):** startTracking creates ride & sets tracking; saves trackpoint when tracking; not when not tracking; stopTracking sets endTime + not-tracking.
- **trackPoints (4):** initially empty; appends one/multiple; second start resets.
- **distance (4):** initially 0; first point stays 0; second increases; second start resets.
- **speed (6):** initially null; provider speed used; first fix w/o speed null; computed fallback; updates even when not tracking; not reset on stop.
- **elapsed (4):** initially 0; timer starts; stops on stop; resets on second start.
- **pause/resume (10):** isPaused initial/set/clear; pause no-op when not tracking; paused doesn't save but updates live location; pause freezes timer; resume continues from frozen value; pause doesn't accumulate distance; resume doesn't count break gap.
- **Filter edge cases (7):** high-inaccuracy discarded; stale fix rejected entirely; stale first fix → route starts from fresh fix, distance not inflated; fresh fix recorded; mid-ride teleport dropped, good points survive; near-zero provider speed not recorded; real provider speed recorded.
- **ConnectivityObserver (new):** probe success → online; probe failure/exception → offline; no-network fast-path → offline; re-emits on a connectivity event; `distinct` (no duplicate emissions).

**Acceptance (Part A):** `flutter analyze` clean; all 39 ported + connectivity tests green. No Flutter plumbing imports in `ride_tracker.dart` (only Dart + domain + data types).

---

## Part B — Platform plumbing (spike first, then device-validated)

> **Advisor guidance:** background location is the only piece that does NOT port cleanly and differs fundamentally on iOS. **Spike before full build-out.**

### B0. Spike (throwaway, before B1–B4)
On a real Android device **and** an iOS device/simulator: prove `geolocator` background fixes arrive with screen off, `flutter_foreground_task` keeps the service alive (Android), and iOS `UIBackgroundModes: location` + "Always" delivers fixes. Capture findings; only then implement B1–B4. If a blocker appears (e.g. unreliable background on a target), surface options before proceeding.

### B1. `LocationSource` (`lib/tracking/location_source.dart`)
`abstract interface class LocationSource { Stream<LocationFix> get fixes; Future<bool> ensurePermission(); }` + `GeolocatorLocationSource` impl: high-accuracy, ~1s interval; maps each `Position` to a `LocationFix`.

> **CRITICAL (advisor):** `LocationFix.elapsedRealtimeNanos` MUST be the fix's **real capture time** from `Position.timestamp` (converted to ns), NOT a clock read at ingestion. Synthesizing it at ingestion makes `now − fixTime ≈ 0` for every fix, turning the freshness filter (stage 0) into a no-op and reintroducing the stale-cached-fix "teleport" bug. Compute both the freshness age and the inter-fix `elapsedS` from `Position.timestamp`. Wall-clock (not monotonic) is the accepted trade — geolocator exposes no monotonic clock, and a 5 s threshold is still robust for catching minutes-old cached fixes. The production default `nowNanos` already reads the same wall-clock source.

### B2. Foreground service + notification (Android) — `flutter_foreground_task`
Ongoing notification with **pause / resume / stop** actions + tap deep-link into the active ride; actions drive `RideTracker.pause()/resume()/stopTracking()`. Notification shows live elapsed/distance (mirrors today). `START_STICKY`-equivalent restart behavior.

### B3. iOS background location
Info.plist: `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, `UIBackgroundModes: [location]`; request **Always** authorization; `allowsBackgroundLocationUpdates`. (Lock-screen pause/resume/stop = Live Activity in Spec 6; here iOS shows an ongoing local notification + records in background.)

### B4. Permissions & manifest
Android: `ACCESS_FINE/COARSE_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `POST_NOTIFICATIONS`. Wire `RideTracker`, `LocationSource`, `ConnectivityObserver` as Riverpod providers; `main()` calls `initializeDateFormatting()` + sets up `PreferencesRepository` override.

**Acceptance (Part B):** manual device checks on **both** OSes — record with screen off; Android notification pause/resume/stop + deep-link; iOS background recording; offline/flight-mode (recording continues, route draws, banner shows). No automated gate (platform behavior).

---

## Branch / integration
`phase/05-gps-tracking` — Part A merges once its tests are green; Part B lands after the spike + device validation. Rebased + fast-forwarded onto `main`, branch deleted.

## Out of scope
iOS Live Activity (Spec 6), the live map rendering (Spec 7), the active-ride UI (Spec 12 — consumes `RideTracker` state).
