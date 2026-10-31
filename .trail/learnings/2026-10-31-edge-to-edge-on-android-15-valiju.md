---
title: "Edge-to-edge on Android 15 needs no change, and the portrait lock stays"
author: Valiju
date: 2026-10-31
branch: main
cost: { minutes: 1, tokens: 10046 }
id: l-a147d222
scope: repo
status: active
src: agent
touches:
  - docs/android-release.md
---

## Decided
Play Vitals hints for release 1.3.1+8 (#82, #84): no code change for edge-to-edge, and the portrait-only lock stays on purpose because Retrail is a phone app. Android 16 ignores the lock on tablets and foldables; we accept that.

## Tried and ruled out
Fixing the edge-to-edge hint in app code. A full walk through the app on Android 15 showed nothing hidden behind the status or gesture bar: onboarding, home, history, settings, countdown, recording, stop dialog, post-ride dialog, ride menu and the edit sheet.

In the code: checked with the emulator image system-images;android-35;google_apis_playstore;x86_64 (AVD Retrail_A15, pixel_9) and a debug build (applicationId io.github.valijuu.retrail.debug). Shortcuts: adb shell pm grant for POST_NOTIFICATIONS and ACCESS_FINE_LOCATION skips the permission dialogs, adb emu geo fix <lon> <lat> feeds GPS points, adb shell pm clear resets onboarding.

## Watch out
Typing blind taps with adb is fragile: a miss opens the photo picker on the profile step. Take a screenshot between steps.
