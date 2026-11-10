---
title: "Sample rides for a device check go into the debug app next to the store app, written with the app's own repository"
author: Valiju
date: 2026-11-10
branch: feature/history-map
id: l-d498f555
scope: repo
status: active
src: agent
touches:
  - android/app/build.gradle.kts
---

## Decided
- A device check installs the debug build (own app id with a debug suffix, own data) with `adb install -r`, so the store app and its rides stay untouched. Sample rides are made synthetic (invented loops, no real traces) by a throw-away test that uses the app's own ride repository, so stats and elevation match what the app writes. Rides are left without outlines on purpose: opening the map then runs the real background fill.
- The database and a preferences file (onboarding done, language) are copied in with `run-as` while the debug app is empty and stopped.

## Tried and ruled out
- Overwriting an existing database in the debug app: refused, it may hold the developer's own test rides. Check with `run-as ... ls` first and only seed an app that has no data directory yet.

## Watch out
- The throw-away generator must not be committed (it would bring invented but realistic-looking data into a public repo for no gain).
- The debug build is slower than release, so performance with many rides is only indicative.

In the code: android/app/build.gradle.kts (debug application id suffix); the FlutterSharedPreferences.xml keys are prefixed `flutter.`.
