---
title: "A hill ride is simulated on a real Android phone with a scripted location source, not with adb mock GPS"
author: Valiju
date: 2026-11-10
branch: feature/elevation
id: l-6974a1e4
scope: repo
status: active
src: agent
touches:
  - integration_test/store_screenshots_test.dart
---

## Decided
Altitude cannot be faked on a real phone through the shell: `adb shell cmd location providers set-test-provider-location` only takes position, accuracy and time, and needs the shell allowed as mock location app first. A device check of elevation therefore runs an integration test on the phone with a scripted LocationSource (1 fix per second, altitude profile with a spike) and takes screenshots with `adb exec-out screencap -p` when the test prints a marker.
The debug build has the id suffix `.debug`, so it installs next to the store app and leaves its data alone.

## Tried and ruled out
`adb shell appops set com.android.shell android:mock_location allow` plus a test provider: works for position, but no altitude option. Reverted afterwards with `deny` and `remove-test-provider`.

## Watch out
Fixes must carry the current time and move about 10 m per second, otherwise the freshness and outlier filters drop them. `flutter test integration_test` uninstalls the debug app at the end.

In the code: pattern taken from the replay source in integration_test/store_screenshots_test.dart.
