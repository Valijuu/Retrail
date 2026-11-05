---
title: "Wobbly route lines in store shots came from the demo GPS scatter, not from the map"
author: Valiju
date: 2026-11-05
branch: feature/ios-screenshots
cost: { minutes: 20, tokens: 217270 }
id: l-fe01eaff
scope: repo
status: active
src: agent
touches:
  - store/ios/screenshot_frame.html
  - store/ios/screenshots.tsv
  - tool/render_ios_store_graphics.sh
  - tool/demo_rides/build_demo_db_test.dart
---

## Decided
The demo rides now scatter each fix by about 0.15 m instead of 1 m. At 1 m the blue route line looked jagged on the iOS Simulator map (high zoom, 3x pixels) in the live and follow shots.

In the code: tool/demo_rides/build_demo_db_test.dart (jitter in _simulate).

## Tried and ruled out
Fixing it in the frame or the render script: the wobble is in the recorded line, so only new raw shots help.

## Watch out
The demo database is built by the iOS screenshots workflow, so the change shows only after a new run. The workflow cancels a running job when the branch is pushed again; do not push while a run is in progress unless you want it restarted.
