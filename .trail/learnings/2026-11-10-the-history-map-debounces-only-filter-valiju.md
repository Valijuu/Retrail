---
title: "The history map debounces only filter changes, and long-running loops reread their conditions instead of trusting a rebuild"
author: Valiju
date: 2026-11-10
branch: feature/history-map
id: l-2c512f2c
scope: repo
status: active
src: agent
touches:
  - lib/features/history_map/outline_fill.dart
  - lib/features/history_map/history_map_providers.dart
  - lib/features/history/area_providers.dart
  - lib/features/history_map/history_map_view.dart
  - lib/map/overview_map.dart
---

## Decided
- The 150 ms settle applies to filter and radius changes only. Outline arrivals from the background fill must pass straight through, or a fast fill keeps restarting the delay and the map stays empty until the last ride is done.
- The background fill loop rereads "map visible or area set, and app in front" at every step. Nobody listens to the controller once the map view is left, and a provider without listeners is not rebuilt, so a flag cached in the rebuild never turns false.
- The camera frames only when a filter that selects rides changed and the new rides have arrived (not while a reload still carries the old ones), and not for sort, favourite toggles or the radius.

## Tried and ruled out
- One debounce delay inside the overview provider: restarted by every outline arrival.
- Framing on the first provider event after a filter change: that event is the loading state with the old rides.

## Watch out
- A map inside the tab swipe needs eager gesture recognizers, or a sideways pan changes the tab (only verifiable on a device).

In the code: lib/features/history_map/outline_fill.dart, lib/features/history_map/history_map_providers.dart (settled rides), lib/features/history/area_providers.dart (settled area), lib/features/history_map/history_map_view.dart (framing), lib/map/overview_map.dart (gestureRecognizers).
