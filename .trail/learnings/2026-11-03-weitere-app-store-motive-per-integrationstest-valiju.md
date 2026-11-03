---
title: Weitere App-Store-Motive per Integrationstest mit Ack-Datei
author: Valiju
date: 2026-11-03
branch: feature/ios-screenshots
cost: { minutes: 39, tokens: 52617 }
id: l-6d104e3a
scope: repo
status: active
src: agent
touches:
  - tool/ios_screenshots.sh
  - integration_test/store_screenshots_test.dart
---

## Decided
- The motives other than home come from integration_test/store_screenshots_test.dart, run by tool/ios_screenshots.sh with `flutter test -d <udid>`, because the simulator cannot tap from the command line and the test's own screenshot misses the MapLibre platform view.
- Handshake: the test prints `RETRAIL_SHOT <name>` and waits for an ack file in its Documents (shot_ack/<name>); the script writes it via `simctl get_app_container`, because a fixed sleep cannot cover the runner's varying delays.
- The demo database is copied in on `RETRAIL_SETUP` (after flutter installed the test build), because flutter test installs its own build and uninstalls it at the end.
- The loop only shoots and acks; the OCR checks run after the test, because in run 41634306589 one OCR pass took 2 min while the ride map rendered.

## Tried and ruled out
- OCR in the read loop: the test gave up on the countdown ack, finished, flutter uninstalled the app, and the 07_track shot showed the iOS home screen with `get_app_container` failing (NSPOSIXErrorDomain code 2). It looked like a crash at ride start, but it was not: the test had already ended.

## Watch out
- The flow can be checked on a local Android emulator (adb screencap, `run-as … app_flutter/shot_ack`), much faster than a 30-min iOS run.
- A green test run does not prove the shots: look at every PNG.
