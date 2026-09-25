# iOS Live Activity Implementation Plan

> **For agentic workers:** executed natively (superpowers:executing-plans) in the authoring session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the active ride as an iOS Live Activity (lock screen + Dynamic Island) with Pause/Resume/Stop and tap-to-open, driven by the existing `RideForegroundService` seam.

**Architecture:** A new `LiveActivityService` implements `RideForegroundService` over a `retrail/live_activity` MethodChannel; the provider picks it on iOS. A pure snapshot module decides content + when to push. Swift: a bridge in Runner, shared attributes/intent, and a new widget-extension target. A GitHub Actions macOS job builds an encrypted unsigned `.ipa` as the compile gate.

**Tech Stack:** Flutter/Riverpod, `MethodChannel`, Swift 5 / ActivityKit / WidgetKit / AppIntents, GitHub Actions.

**Spec:** `docs/specs/06-live-activity.md`

## Global Constraints

- Live Activity requires iOS ≥ 16.1; buttons iOS ≥ 17; Runner stays at deployment target 13.0.
- No App Group, no APNs, no new Dart packages or pods; remove `flutter_local_notifications`.
- No user-facing literals in Swift or Dart widgets — text from ARB via `rideNotificationCopyProvider`; no hex outside `AppColors`.
- Channel name `retrail/live_activity`; action ids are `RideNotificationIds` (`ride_pause|ride_resume|ride_stop|ride_open`).
- Extension bundle id `com.retrail.retrail.RideActivity`; URL `retrail://ride`.
- CI artifact: only `Retrail.ipa.7z` (password `secrets.IPA_PASSWORD`), `retention-days: 3`.
- A Live Activity failure must never break or block recording.

## Review Focus

1. Channel throws (`PlatformException` / `MissingPluginException` on older iOS, Live Activities disabled) → recording continues; covered in Task 3 tests.
2. `update` arriving before `start` finished or after `stop` → nothing is sent; Task 3.
3. Pause → resume must not count paused time: resume pushes a fresh snapshot (`shouldPush` on `isPaused` flip); Task 1.
4. German locale → comma decimal in `distanceText`; Task 1.
5. Unknown action id from Swift → ignored, no crash; Task 2.

---

### Task 1: Snapshot logic (EXACT, `tdd-dart`)
**Files:** Create `lib/domain/live_activity_snapshot.dart`, `test/domain/live_activity_snapshot_test.dart`
**Produces:** `class LiveActivityContent {title, distanceText, isPaused, elapsedSeconds, snapshotEpochMs; toMap()}`, `LiveActivityContent liveActivityContent({required bool isPaused, required int elapsedSeconds, required double distanceMetres, required String recordingTitle, required String pausedTitle, required String locale, required int nowEpochMs})`, `bool shouldPush(LiveActivityContent? last, LiveActivityContent next)`.
(Takes plain values, not `RideTrackingState`/`RideNotificationCopy`, so `lib/domain` stays free of `tracking` imports.)
- [ ] Test list → red/green per test → refactor → commit.

### Task 2: Shared control relay (RGR)
**Files:** Create `lib/tracking/ride_control_relay.dart`, `test/tracking/ride_control_relay_test.dart`; Modify `lib/main.dart` (use relay).
**Produces:** `void rideControlRelay(ProviderContainer container, String id)`.
- [ ] Failing tests (pause/resume/stop/open/unknown) → implement → main.dart uses it → commit.

### Task 3: `LiveActivityService` + provider selection (RGR)
**Files:** Create `lib/tracking/live_activity_service.dart`, `test/tracking/live_activity_service_test.dart`; Modify `lib/tracking/tracking_providers.dart`, `test/tracking/tracking_providers_test.dart`, `lib/main.dart` (register incoming `action` handler → relay; end stale activities on launch).
**Consumes:** Task 1, Task 2. **Produces:** `LiveActivityService(MethodChannel, RideNotificationCopy Function(), LiveActivityAccents, {NowMs now})`, `static const channel`, `void listenForActions(void Function(String id))`.
- [ ] Failing tests per spec §Test-first → implement → provider switch → commit.

### Task 4: Swift — shared types, bridge, widget extension
**Files:** Create `ios/Shared/RideActivityAttributes.swift`, `ios/Shared/RideControlIntent.swift`, `ios/Runner/LiveActivityBridge.swift`, `ios/RideActivityExtension/{RideActivityBundle.swift,RideActivityWidget.swift,Info.plist,Assets.xcassets}`; Modify `ios/Runner/AppDelegate.swift`, `ios/Runner/SceneDelegate.swift`, `ios/Runner/Info.plist`, `ios/Runner.xcodeproj/project.pbxproj`.
- [ ] Write files → pbxproj target + embed phase → `plutil`-style lint of plists (python `plistlib`) → commit.

### Task 5: CI build + deps + docs
**Files:** Create `.github/workflows/ios-build.yml`, `docs/ios-sideloading.md`; Modify `pubspec.yaml`, `android/app/build.gradle.kts`, `CLAUDE.md`, spec status.
- [ ] Remove `flutter_local_notifications` (+ desugaring only it needed) → `flutter analyze` + `flutter test` → push branch, trigger workflow, iterate until green → close #35 → rebase/ff main.
