# Spec 6 — iOS Live Activity (lock screen + Dynamic Island)

**Status:** IMPLEMENTED (headless) — Dart side test-first (EXACT snapshot + RGR service/relay/provider), Swift + Xcode target written by hand; **awaiting the `ios-build` CI run and the device checklist** (§H, `docs/ios-sideloading.md`).
**Phase:** 6 of 15 (the iOS counterpart to Spec 5B's Android notification)
**Depends on:** Spec 5A (`RideTracker`, `RideTrackingState`), Spec 5B (`RideForegroundService`
seam, `RideRecordingController`, the notification-action relay in `main.dart`,
`rideNotificationCopyProvider`), Spec 8 (`pendingRideDeepLinkProvider`), Spec 15
(`NSSupportsLiveActivities` already declared).
**Branch:** `phase/06-live-activity`
**Closes:** issue #35 (`flutter_local_notifications` is dropped — see §F).

---

## Goal

While a ride records on iOS, show a **Live Activity** on the lock screen and in the Dynamic Island
that does what the Android ongoing notification does (Spec 5B §B2):

- title **"Recording ride"** / **"Ride paused"**,
- live **elapsed time** and **distance**,
- **Pause/Resume** (toggle) + **Stop** buttons,
- **tap → open the active ride**.

Recording itself is untouched: `RideTracker` stays the single source of truth; the Live Activity
is a *view* of it, exactly like the Android notification.

### The scoping reality (read first)

Development happens on **Linux without a Mac**. Consequences, accepted in review:

- Swift / SwiftUI / the Xcode target **cannot be compiled or run locally**. The Dart side is fully
  tested here; the Swift side is verified by a **GitHub Actions macOS build** (§G) — the repo is
  public, so macOS runners are free.
- The new Xcode target is added to `project.pbxproj` **by hand**, following Xcode's own
  widget-extension template (no Ruby/`xcodeproj` gem on this machine). The CI build is the check.
- Device testing uses the CI's **unsigned `.ipa`**, sideloaded from Linux with a **free Apple ID**
  (Splice, §H) — no paid Apple Developer account. So the design must not need any paid-only
  capability: **no App Group, no push (APNs) updates**.

---

## A. Architecture

```
RideTracker ──changes──► RideRecordingController ──update()──► RideForegroundService
                                                                  ├─ Android: ForegroundTaskService (unchanged)
                                                                  └─ iOS:     LiveActivityService ──MethodChannel──► LiveActivityBridge.swift ──ActivityKit──► RideActivityExtension (SwiftUI)
Live Activity button (iOS 17+) ──LiveActivityIntent.perform()──► LiveActivityBridge ──"action" call──► rideControlRelay() ──► RideRecordingController
Live Activity tap ──retrail://ride──► SceneDelegate ──► LiveActivityBridge ──"action" ride_open──► rideControlRelay() ──► pendingRideDeepLinkProvider
```

- **`LiveActivityService implements RideForegroundService`** (`lib/tracking/live_activity_service.dart`).
  The existing seam already has exactly the needed lifecycle: `start` / `update` / `stop` /
  `ensureNotificationPermission`. No change to `RideRecordingController`.
- **Platform choice** in `rideForegroundServiceProvider`: iOS → `LiveActivityService`, everything
  else → `ForegroundTaskService` (unchanged). On iOS `flutter_foreground_task` is then no longer
  started at all: background recording on iOS comes from `geolocator`
  (`allowsBackgroundLocationUpdates`, Spec 5B §B3), not from the plugin, and its plain iOS
  notification is replaced by the Live Activity.
- **One relay for both platforms.** The body of `FlutterForegroundTask.addTaskDataCallback` in
  `main.dart` moves to `rideControlRelay(ProviderContainer, String id)`
  (`lib/tracking/ride_control_relay.dart`). Android's task-data callback and iOS's channel handler
  both call it, so `ride_pause` / `ride_resume` / `ride_stop` / `ride_open` mean the same thing
  everywhere. `rideActionFromId` / `RideNotificationIds` are reused as-is.

### Channel contract — `retrail/live_activity`

Dart → Swift (`invokeMethod`):

| Method | Arguments | Result |
|---|---|---|
| `isSupported` | — | `bool`: iOS ≥ 16.1 **and** `ActivityAuthorizationInfo().areActivitiesEnabled` |
| `start` | `attributes` map + `content` map (below) | — (ends any existing Retrail activity first) |
| `update` | `content` map | — (no-op when no activity is running) |
| `end` | — | — (ends all Retrail activities, dismissal `.immediate`) |

Swift → Dart (`invokeMethod` on the same channel): `action` with a `String` id
(`ride_pause` | `ride_resume` | `ride_stop` | `ride_open`).

`attributes` (static for the activity's lifetime): `pauseLabel`, `resumeLabel`, `stopLabel`,
`accentLight`, `accentDark` (ARGB ints).
`content` (dynamic): `title`, `distanceText`, `isPaused`, `elapsedSeconds`, `snapshotEpochMs`.

## B. Content & update cadence — pure logic (EXACT)

`lib/domain/live_activity_snapshot.dart` — side-effect-free, so it is built with the **`tdd-dart`
EXACT** workflow.

- `LiveActivityContent` (immutable, value equality): `title`, `distanceText`, `isPaused`,
  `elapsedSeconds`, `snapshotEpochMs`.
- `LiveActivityContent liveActivityContent({required RideTrackingState state, required
  RideNotificationCopy copy, required int nowEpochMs})` —
  `title` = `copy.pausedTitle` when paused else `copy.recordingTitle`;
  `distanceText` = `formatDistanceKm(state.distanceMetres, locale: copy.locale)` (same formatter
  and locale as the Android notification body).
- `bool shouldPush(LiveActivityContent? last, LiveActivityContent next)` — true when there is no
  `last`, or `isPaused`, `title` or `distanceText` differ. **Elapsed time alone never triggers a
  push**: the widget counts it natively (below). Net effect: at most one update per 10 m of
  distance (the `X.XX km` resolution) plus one per pause/resume — well inside ActivityKit's
  update budget, and no per-second channel traffic.

**Elapsed time rendering (Swift).** Running: `Text(timerInterval: start...Date.distantFuture,
countsDown: false)` with `start = snapshot − elapsedSeconds`, so iOS ticks it itself. Paused: a
static `M:SS` / `H:MM:SS` string of `elapsedSeconds`. Every pause/resume pushes a fresh snapshot,
so paused time is never counted. *Accepted deviation:* iOS's timer uses `M:SS` / `H:MM:SS`
instead of the Android body's `formatElapsed` output.

## C. `LiveActivityService` (Riverpod/service layer — Red-Green-Refactor)

- `start()`: `isSupported` false → remember "inactive", return (no throw). Else `start` with
  attributes from `rideNotificationCopyProvider` + `AppColors.light/dark.primary`, and the initial
  content (`elapsedSeconds: 0`, `distanceMetres: 0`).
- `update(isPaused, elapsedSeconds, distanceMetres)`: build content via §B from the current
  tracker values; push only if active and `shouldPush(last, next)`.
- `stop()`: `end`, forget `last`.
- `ensureNotificationPermission()`: returns `true` — Live Activities need no notification
  permission.
- **Every channel call is wrapped:** a `PlatformException` / `MissingPluginException` is logged in
  debug and swallowed. A Live Activity failure must never break or block recording.

The service needs the full `RideTrackingState` for §B but `update()` only receives three values —
it builds a minimal `RideTrackingState(isPaused:, elapsedSeconds:, distanceMetres:)` from them. No
interface change.

## D. Swift side

### Files

```
ios/Shared/RideActivityAttributes.swift   # ActivityAttributes + ContentState  (Runner + extension)
ios/Shared/RideControlIntent.swift        # LiveActivityIntent, iOS 17+        (Runner + extension)
ios/Runner/LiveActivityBridge.swift       # MethodChannel handler, ActivityKit calls (Runner only)
ios/RideActivityExtension/RideActivityBundle.swift   # @main WidgetBundle
ios/RideActivityExtension/RideActivityWidget.swift   # ActivityConfiguration: lock screen + Dynamic Island
ios/RideActivityExtension/Info.plist                 # NSExtensionPointIdentifier = com.apple.widgetkit-extension
ios/RideActivityExtension/Assets.xcassets            # the Retrail mark (template image) only — no colors
```

- **`RideActivityAttributes`**: static labels + accent colors; `ContentState` mirrors the channel
  `content` map (`Codable, Hashable`).
- **`RideControlIntent: LiveActivityIntent`** (`@available(iOS 17, *)`), one `action` string
  parameter. `perform()` runs **in the app's process** (the app is alive — it is recording with
  background location) and posts the id to `LiveActivityBridge`, which forwards it to Dart. Must
  be a member of **both** targets, otherwise the button compiles in the extension but never
  reaches the app.
- **`LiveActivityBridge`**: registered from `AppDelegate.didInitializeImplicitFlutterEngine`
  (same place as `GeneratedPluginRegistrant`). All ActivityKit code is behind
  `if #available(iOS 16.1, *)`; below that every call is a no-op and `isSupported` is false.
- **Tap → open**: `.widgetURL(URL(string: "retrail://ride"))`. Register the `retrail` URL scheme
  (`CFBundleURLTypes`) in `Runner/Info.plist`; `SceneDelegate.scene(_:openURLContexts:)` hands
  `retrail://ride` to the bridge, which sends `ride_open`. Any other URL goes to `super`.

### Layouts (SwiftUI)

- **Lock screen / banner:** leading Retrail mark + title; below it the elapsed timer (large,
  monospaced digits) and the distance; trailing **Pause/Resume** + **Stop** buttons.
- **Dynamic Island — expanded:** leading mark + title, trailing distance, center/bottom the timer
  and the two buttons. **Compact:** leading mark, trailing timer. **Minimal:** mark only.
- **Buttons only on iOS 17+** (`Button(intent:)`); on 16.1–16.x the same layout without buttons —
  tapping still opens the ride.
- **Colors:** only the `accentLight`/`accentDark` passed in from `AppColors.primary`, chosen by
  `@Environment(\.colorScheme)`; everything else uses system semantic colors (`.primary`,
  `.secondary`). No hex literals in Swift. All user-facing text comes from Dart (ARB) via
  attributes/content — no string literals in Swift.

### Stale activities

- `start` ends any existing Retrail activity before requesting a new one.
- On app launch (bridge registration) all leftover Retrail activities are ended — a killed
  process otherwise leaves a frozen activity for up to 8 h. Pairs with
  `finalizeUnfinishedRides()` in `main.dart`.
- `applicationWillTerminate`: best-effort `end` (not guaranteed to run).
- Every push sets `staleDate = now + 15 min`, so an orphaned activity visibly goes stale instead
  of pretending to record.

## E. Xcode project (`ios/Runner.xcodeproj/project.pbxproj`)

Hand-written, mirroring Xcode's "Widget Extension" template:

- New native target **`RideActivityExtension`**, product type
  `com.apple.product-type.app-extension`, bundle id `com.retrail.retrail.RideActivity`,
  `IPHONEOS_DEPLOYMENT_TARGET = 16.1`, `SWIFT_VERSION = 5.0`, `INFOPLIST_FILE =
  RideActivityExtension/Info.plist`, `SKIP_INSTALL = YES`, frameworks `WidgetKit` + `SwiftUI`
  (+ `AppIntents` weak-linked for iOS 17 buttons).
- Runner: **"Embed Foundation Extensions"** copy-files phase (dstSubfolderSpec 13) embedding
  `RideActivityExtension.appex`, plus a target dependency on the extension.
- `ios/Shared/*.swift` in the Sources phase of both targets.
- Runner stays at `IPHONEOS_DEPLOYMENT_TARGET = 13.0` (Live Activity code is availability-gated).
- Add `de` to `knownRegions` if still missing (Spec 5B note).
- `Runner/Info.plist`: `NSSupportsLiveActivities` (already there) + `CFBundleURLTypes` (`retrail`).

## F. Dependencies

- **Remove `flutter_local_notifications`** from `pubspec.yaml` — it was only ever kept for this
  iOS pass (issue #35) and the Live Activity replaces it. Verify no import remains, close #35.
- No new Dart packages (plain `MethodChannel`). No new CocoaPods.
- `CLAUDE.md` tech-stack "Notifications" row: update to "iOS: Live Activity (ActivityKit widget
  extension, native MethodChannel)" in the same change.

## G. CI — `.github/workflows/ios-build.yml`

- Runner `macos-15`; triggers: push to `main` and `phase/**` (so a phase branch is compile-checked before it lands) + `workflow_dispatch`. Also fails if the `.appex` was not embedded.
- Steps: checkout → `subosito/flutter-action` (stable, cached) → `flutter pub get` →
  `flutter build ios --release --no-codesign --dart-define=MAPTILER_KEY=${{ secrets.MAPTILER_KEY }}`
  → package `build/ios/iphoneos/Runner.app` as `Payload/Runner.app` → zip to `Retrail.ipa` →
  **encrypt**: `7z a -p"$IPA_PASSWORD" -mhe=on Retrail.ipa.7z Retrail.ipa` (AES-256, file names
  hidden) → `actions/upload-artifact` of **only the `.7z`** with **`retention-days: 3`**.
- **The green build is the automated gate for all Swift / pbxproj work in this spec.**
- **Why encrypted:** the repo is public, so workflow artifacts are downloadable by any signed-in
  GitHub user, and the MapTiler key is compiled into the app. With the encrypted archive only the
  holder of `IPA_PASSWORD` can open the build. Secrets are masked in logs, and the workflow only
  runs on pushes to `main` / manual dispatch (never on fork PRs), so secrets never reach
  third-party code.
- The key is still extractable from any build that *is* handed out (sideloaded or, later,
  published) — normal for client-side map keys. Mitigation lives outside the repo: watch usage in
  the MapTiler dashboard, apply whatever key restrictions MapTiler offers for native apps, rotate
  the key if it is abused.
- One-time setup (user): repository secrets `MAPTILER_KEY` and `IPA_PASSWORD` (a long random
  passphrase).

## H. Installing on the iPhone (no Mac, no paid account)

Documented in `docs/ios-sideloading.md` (new):

1. Actions → latest `ios-build` run → download the artifact, then
   `7z x Retrail.ipa.7z` with the `IPA_PASSWORD` passphrase → `Retrail.ipa`.
2. Install [Splice](https://github.com/franklintra/splice) on Linux (needs `libimobiledevice`).
3. `splice login` with an Apple ID (a secondary one is recommended by the tool's authors).
4. iPhone: Settings → Privacy & Security → **Developer Mode** on; connect via USB, trust the PC.
5. `splice install Retrail.ipa`. The app runs **7 days**, then `splice refresh` (or the Splice
   background service) re-signs it.
6. Limits: free accounts get **10 App IDs per 7 days**; app + extension use 2 per install.

Community tooling, not an Apple product — may lag behind new iOS releases.

## Localization

**No new ARB keys.** The Live Activity reuses Spec 5B's `notifRecordingTitle`,
`notifRecordingPausedTitle`, `notifActionPause`, `notifActionResume`, `notifActionStop` via
`rideNotificationCopyProvider` (already locale-aware, EN + DE).

## Test-first plan

**EXACT (`tdd-dart`) — `test/domain/live_activity_snapshot_test.dart`:**
- recording → `recordingTitle`; paused → `pausedTitle`.
- `distanceText` uses `formatDistanceKm` with the copy's locale (`de` → comma separator).
- `elapsedSeconds` / `snapshotEpochMs` passed through.
- `shouldPush`: null last → true; only elapsed changed → false; distance below the next 10 m
  step → false; distance text changed → true; pause toggled → true.

**Red-Green-Refactor:**
- `test/tracking/live_activity_service_test.dart` (mock `MethodChannel` via
  `TestDefaultBinaryMessengerBinding`): unsupported → `start`/`update`/`stop` send nothing and
  don't throw; `start` sends attributes (labels + ARGB accents) + initial content; `update` pushes
  only when `shouldPush`; `update` before `start` sends nothing; `stop` sends `end` and a later
  `update` sends nothing; a `PlatformException` from any call is swallowed and recording state is
  unaffected; `ensureNotificationPermission` is `true`.
- `test/tracking/ride_control_relay_test.dart`: `ride_pause` → pause, `ride_resume` → resume,
  `ride_stop` → stop, `ride_open` → `pendingRideDeepLinkProvider` true, unknown id → nothing
  (spy `RideRecordingController` via mocktail).
- `test/tracking/tracking_providers_test.dart` (extend): `rideForegroundServiceProvider` returns
  `LiveActivityService` under `debugDefaultTargetPlatformOverride = TargetPlatform.iOS`,
  `ForegroundTaskService` under Android.
- Channel → relay wiring: an incoming `action` call on `retrail/live_activity` reaches
  `rideControlRelay`.

**Build-gated (automated, CI):** the `ios-build` workflow is green — Swift compiles, the extension
is embedded, `Runner.app` packages.

**Device-gated (manual, iPhone with iOS 17+):**
- Start a ride → Live Activity appears on the lock screen and in the Dynamic Island (if present).
- Elapsed ticks every second with the screen locked; distance updates while moving.
- Pause from the lock screen → title "Ride paused", timer frozen, app state paused; Resume
  continues without counting the pause.
- Stop from the lock screen → ride saved (appears in history), activity disappears.
- Tap the activity → app opens on the active-ride screen.
- DE device language → German title/buttons, comma decimal.
- Live Activities disabled in Settings → ride still records normally, no activity.
- Force-quit the app mid-ride, relaunch → no stale activity left behind.

## Acceptance

- `flutter analyze` clean; `flutter test` green (incl. the tests above).
- `ios-build` GitHub Actions workflow green on `main`.
- `flutter_local_notifications` removed, issue #35 closed, `CLAUDE.md` tech-stack row updated.
- Device checklist above passes on a real iPhone (sideloaded per §H). Until then the status is
  **IMPLEMENTED (headless + CI build)**, like Spec 5B.

## Out of scope

- Push-token / APNs remote updates (needs a paid account; not needed — the app is alive while
  recording).
- A map or route preview inside the Live Activity.
- Any Android change (the Android notification stays exactly as Spec 5B).
- App Store / TestFlight distribution.
