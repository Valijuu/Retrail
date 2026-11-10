---
title: "The history map keeps outlines in one shared in-memory store, loaded by id on demand, and marks routes without an outline with an empty row"
author: Valiju
date: 2026-11-10
branch: feature/history-map
id: l-b41e3cb9
scope: repo
status: active
src: agent
touches:
  - lib/features/history/area_providers.dart
  - lib/features/history/outline_cache.dart
  - lib/data/repositories/outline_repository.dart
  - lib/features/history_map/history_map_providers.dart
  - test/history_map/history_map_view_test.dart
---

## Decided
- The outline store and the "rides inside the area" provider live in the History feature, not in the map feature: the list needs them too (area filter), and the map feature depends on History, never the other way round.
- The database is watched for the ids that have an outline only (no polyline text). Outlines are loaded by id when a ride becomes visible, and ids that vanish are dropped from the cache. This is how "read once", "only changed rides touched" and "select only the outlines of filtered rides" all hold together.
- A route that gives no outline (fewer than two points) gets a row with an empty polyline, so the background fill does not pick the same ride forever. Readers must skip empty outlines.
- Map data (lines per type or heat) is built in an isolate from plain strings; per-ride GeoJSON fragments are cached and merged back after the build.

## Tried and ruled out
- Putting the area provider in the map feature: it makes History import the map feature and the map feature import History (cycle).
- Reusing the History list's action mixin for the map card: it is bound to the History screen state, so the screen passes the card actions in instead.

## Watch out
- Widget tests of the map view: debounce timers run on the fake clock, isolates and Drift queries in real time. Alternate `tester.pump(duration)` and `tester.runAsync(delay)`, and unmount plus pump a second at the end, or the test fails on pending timers.
- The cache is keyed by ride id and only watches which ids have an outline, so rewriting the outline of a cached ride would need an explicit evict.

In the code: lib/features/history/area_providers.dart, lib/features/history/outline_cache.dart, lib/data/repositories/outline_repository.dart (fillNext), lib/features/history_map/history_map_providers.dart, test/history_map/history_map_view_test.dart.
