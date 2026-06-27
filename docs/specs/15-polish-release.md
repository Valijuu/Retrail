# Spec 15 — Polish & release

**Status:** DONE (Part A) — implemented test-first; 265 tests green, analyze clean, debug APK
builds. Part B integration skeleton compiles (device run deferred to 5B/6).
**Phase:** 15 of 15 (final)
**Depends on:** all prior specs (1–14). Touches platform config (Specs 1 shell), the
preview pipeline (Spec 7/12), `RideTracker` (Spec 5), history (Spec 13).
**Branch:** `phase/15-polish-release`

---

## Goal

Take the app from "feature-complete in the simulator's happy path" to "release-shaped":
**Retrail** branding + app icon, the Android manifest and iOS `Info.plist` declarations the
app actually needs (location, foreground service, notifications, photo access, `geo:` navigation
visibility), and a **headless end-to-end flow test** (record → save → history → preview) that
guards the core pipeline in CI. A final `analyze` + full-suite pass closes the migration.

### The scoping reality (read first)

A real "release" includes on-device behavior that **cannot go green on the Linux dev box** and is
already deferred to its own phases:

- **Real background GPS** (foreground-service start, `geolocator` stream, screen-off recording) —
  **Spec 5 Part B**, device-gated.
- **iOS Live Activity / Dynamic Island** — **Spec 6**, net-new Swift, device-gated.

So this spec is **partitioned** into:

- **Part A — green now** (verifiable on the dev box via `flutter analyze` + `flutter test` +
  `flutter build`): branding, app icon, manifest/`Info.plist` *declarations*, headless e2e flow
  test, final cleanup. **This is what the phase's green-gate covers.**
- **Part B — device-gated** (scaffolded here, verified later on real hardware): the actual
  permission prompts, background recording, Live Activity, and an on-device `integration_test`
  run. We lay the static config + a runnable `integration_test/` skeleton so the on-device pass in
  5B/6 has a home, but those runs are **not** part of this phase's green-gate.

---

## Part A — green now

### A1. Branding & app identity

| Target | Now | Change |
|---|---|---|
| Android `android:label` | `retrail` (lowercase) | `Retrail` (move to `@string/app_name` in a values resource, EN + DE both `Retrail`) |
| Android `applicationId` / `namespace` | `com.retrail.retrail` | **keep** — fresh install, no store continuity (the roadmap's `com.retrail.app` was a pre-build assumption; the project was created as `com.retrail.retrail`). Noted, not changed. |
| iOS `CFBundleDisplayName` | `Retrail` | keep |
| iOS `CFBundleName` | `retrail` | `Retrail` (align the internal name too, so nothing user-visible is lowercase) |
| Flutter `onGenerateTitle` | `appTitle` ARB | already `Retrail` via `app_en.arb`/`app_de.arb` — verify |

**The display name is `Retrail` on every surface** — Android launcher label, iOS home-screen name,
the in-app title, and the recents/task-switcher entry. The only intentionally-lowercase identifiers
left are the non-visible package/bundle IDs (`applicationId` / `namespace = com.retrail.retrail`),
which users never see.

Android label via a string resource (`android/app/src/main/res/values/strings.xml` →
`<string name="app_name">Retrail</string>`) referenced as `android:label="@string/app_name"`,
mirroring the original. No Dart change.

### A2. App icon

Add **`flutter_launcher_icons`** (dev dependency) and generate adaptive (Android) + iOS icons
from a single source asset:
- Source: `assets/branding/app_icon.png` (1024×1024, the Retrail mark). The original Android icon
  is an adaptive `ic_launcher_foreground` over `ic_launcher_background`; we reproduce the same mark
  as a flat 1024² master and let `flutter_launcher_icons` emit all densities + the adaptive XML.
- Config block in `pubspec.yaml`:
  ```yaml
  flutter_launcher_icons:
    android: true
    ios: true
    image_path: "assets/branding/app_icon.png"
    adaptive_icon_background: "#FFF8F5"   # Surface token (no new hex)
    adaptive_icon_foreground: "assets/branding/app_icon_foreground.png"
    remove_alpha_ios: true
  ```
- Run `dart run flutter_launcher_icons` to generate; commit the generated mipmaps/asset catalog.
- Background uses the **Surface** token `#FFF8F5` (already in the design-token table — not a new hex).

> **Art decision (resolved):** no new art was needed — the source reuses the original app's
> existing Retrail mark (the brown map-pin + dashed route trail on the Surface cream). The original
> adaptive foreground (432²) was upscaled to a 1024² master + a flat cream composite under
> `assets/branding/`; swapping in a higher-res master later is a one-liner that changes none of the
> wiring.

### A3. Android manifest — declarations (`android/app/src/main/AndroidManifest.xml`)

Port the original's permission set and the `location` foreground service **declaration** (the
service *implementation* is Spec 5B; declaring it now is harmless and keeps the manifest
release-shaped). Add:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```
Plus the `geo:` package-visibility `<queries>` block (so the "navigate to start" `url_launcher`
`geo:` intent — already used by history cards — resolves on Android 11+):
```xml
<queries>
  <intent>
    <action android:name="android.intent.action.VIEW"/>
    <data android:scheme="geo"/>
  </intent>
</queries>
```
The `flutter_foreground_task` plugin contributes its own service entry; we do **not** hand-author
the `LocationService` (that's the plugin's job in 5B). No `AppCompat` locale service (Flutter does
locale in-app — Spec 14). Label → `@string/app_name`.

### A4. iOS `Info.plist` — declarations (`ios/Runner/Info.plist`)

Add the usage strings + background modes the features require (each key is the user-facing prompt
copy; iOS reads these from `Info.plist`, not ARB):

| Key | Purpose | Value (EN) |
|---|---|---|
| `NSLocationWhenInUseUsageDescription` | foreground GPS recording | "Retrail records your route while you ride." |
| `NSLocationAlwaysAndWhenInUseUsageDescription` | background recording (5B) | "Retrail keeps recording your route when the screen is off." |
| `NSPhotoLibraryUsageDescription` | profile photo (`image_picker`) | "Choose a profile photo from your library." |
| `NSCameraUsageDescription` | profile photo (camera) | "Take a profile photo." |
| `UIBackgroundModes` | `location` (array) | background location |
| `NSSupportsLiveActivities` | Live Activity scaffold (Spec 6) | `true` |

`NSSupportsLiveActivities` + `UIBackgroundModes:location` are **declarations only** — the Live
Activity extension (Spec 6) and the background stream (5B) light them up later. German prompt copy
goes in `ios/Runner/de.lproj/InfoPlist.strings` (faithful to the DE reference register).

### A5. Headless end-to-end flow test (`test/e2e/record_save_history_preview_test.dart`)

The phase's flagship green deliverable — guards the **core pipeline wiring** end to end without a
device, using the existing testable seams (faked photo/render/tracking, in-memory Drift):

1. Drive `RideTracker` by feeding a short synthetic track (the same seam the 40+ `RideTrackerTest`
   cases use) → assert live distance/duration/maxSpeed advance.
2. `ActiveRideController.stopRide()` then `saveRide(title, comment, favorite)` → assert the ride +
   trackpoints persist to the in-memory DB, and `ensurePreview` populates the (faked) preview cache
   keyed by `rideId`.
3. The `historyItemsProvider` (real pipeline over the real DB) now surfaces the saved ride in the
   correct day group, with computed stats.
4. The history card requests its cached preview for that `rideId` (cache hit — no per-scroll
   render), proving the "snapshot once, display forever" contract at the wiring level.

This asserts the **pipeline**, not pixel output (real tile rendering is network/device-gated — the
render fn is faked, as in every prior widget test). It's the integration glue the per-spec tests
each only touched one side of.

### A6. Final cleanup pass

- `flutter analyze` clean; `dart format` clean.
- Confirm no `_Placeholder`/TODO/`debugPrint` left in `lib/`.
- MapTiler attribution present on the live map + a license/attribution note (per the tile
  license) — verify it's wired from Spec 7/12, add if missing.
- Verify `flutter build apk --debug` and `flutter build ios --no-codesign --debug` both succeed
  (build-shape check; not a device run).

---

## Part B — device-gated (scaffolded here, verified in 5B/6 on hardware)

- **`integration_test/app_flow_test.dart`** — a runnable on-device skeleton mirroring A5 but
  through the real UI (onboarding → start → record with a mock location stream → stop → save →
  history → preview). Compiles and is wired into `integration_test/`, but its **on-device run** is
  a 5B/6 deliverable, not this phase's green-gate.
- Real permission prompts, screen-off background recording, notification controls + deep-link,
  iOS Live Activity — all **deferred** (5B/6), unchanged by this spec.

---

## Localization — new ARB keys

None expected in Dart UI (this phase is platform config + tests). Permission copy lives in
`Info.plist` / `InfoPlist.strings` (iOS) and is not ARB. `app_name` is an Android string resource,
not ARB. If the final pass surfaces any in-app release string, add it to both ARB files then.

---

## Test-first plan

- **`test/e2e/record_save_history_preview_test.dart`** (A5) — written first, drives the full
  record→save→history→preview pipeline over in-memory Drift + faked render/tracking seams.
- Existing suites must stay green; the manifest/`Info.plist`/icon changes are static config with no
  unit test, guarded by the `flutter build` shape-check in A6.

All gated by `flutter analyze` clean + full `flutter test` green before the phase is done.

---

## Acceptance

- App shows as **Retrail** with the app icon on both platforms (visual/build check).
- Android manifest declares location/foreground-service/notification permissions + `geo:` queries;
  iOS `Info.plist` declares the location/photo usage strings + background-location + Live-Activity
  support.
- The headless e2e flow test passes: a recorded ride saves, appears in history, and serves a cached
  preview — no per-scroll render.
- `flutter analyze` clean; full `flutter test` green; debug builds succeed on both platforms.

---

## Out of scope (deferred — device hardware required)

- On-device background recording, permission prompts, notification controls + deep-link → **Spec 5
  Part B**.
- iOS Live Activity / Dynamic Island extension → **Spec 6**.
- On-device `integration_test` run + real tile-rendered preview PNG verification → 5B/6 device pass.
