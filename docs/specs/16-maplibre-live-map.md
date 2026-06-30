# Spec 16 — Live map: swap `flutter_map` → native MapLibre

**Status:** DRAFT — awaiting review.
**Phase:** post-roadmap revision of Spec 7 §B (live map). Previews (Spec 7 §A) untouched.
**Depends on:** Spec 7 (LiveMap API + preview pipeline), Spec 12 (active-ride screen embeds LiveMap), Spec 5A (`RideTracker`/`ConnectivityObserver`), Spec 5B (location perms / platform setup).

## Goal
Replace the live/active-ride map's renderer from `flutter_map` (raster tiles on Flutter's canvas) with the **native `maplibre` plugin** (vector tiles, maplibre-native on Android + iOS) **behind LiveMap's existing public API**, so callers, the PNG ride-previews, and the rest of the app are unchanged. This realises the contingency Spec 7 §B already named: *"fall back to a native MapLibre Flutter plugin for the live screen only if it's too jerky."*

**Why now (spike findings, device-verified on Pixel 7):**
- MapLibre vector is **markedly smoother** than `flutter_map` — continuous fractional zoom (no raster "pop"), clean world-fit, better pan/fling.
- The only blemish — a stutter at high zoom while panning dense city centres — is **basemap style weight** (3D building extrusions + label collision in `streets-v2`), **not** the route, the platform-view bridge, debug mode, or any GeoJSON knob. It stuttered on the original Android app too. A lighter style removes it. Flutter's own UI thread measured **0% jank**; the cost was entirely in maplibre-native's GL thread.

**Chosen styles:** `topo-v2` (light) + `basic-v2-dark` (dark). `topo-v2` has no dark twin (`topo-v2-dark` 404s), so dark mode pairs topo-light with the lighter, smooth `basic-v2-dark`. Both confirmed rendering on-device.

**Real-workload verified (Pixel 7):** a **1500-point dense route** panned at high zoom on `topo-v2`, plus an **active-recording simulation** (append a point/sec → `updateGeoJsonSource` → camera-follow at ride zoom) — both **smooth**, including each per-second update. This is the scenario that mattered (not the 12-point spike line) and the one a web search flagged as a MapLibre weak spot ("large FeatureCollection GeoJSON source updates"); it held up, so plugin 0.3.5's `GeoJsonOptions`/synchronous-update stays a follow-up, not a prerequisite. iOS still pending (see Acceptance).

## Non-goals / preserved invariants
- **No change to `LiveMap`'s public API** — same constructor params, same call sites (`active_ride_screen`, history detail/fullscreen dialog). Additive only: an optional `@visibleForTesting` map-builder seam (below).
- **Preview snapshot pipeline (Spec 7 §A) is untouched** — it never used `flutter_map` (pure projection math + `ui.Canvas` + a `TileProvider` interface). History/home thumbnails stay static PNGs.
- **Heading-up rotation stays as-is (none).** Current `LiveMap` does not rotate; this swap keeps parity. MapLibre `animateCamera(bearing:)` makes real heading-up a clean follow-up (see Out of scope).

## A. Public API to keep byte-for-byte
`LiveMap({ key, required points, current, isFollowing = true, initialZoom = 16.5, fitBounds = false, onGesture })` — unchanged.
Pure helpers stay (their unit tests stay green): `CameraFollow`, `followCameraUpdate({wasFollowing, isFollowing, hasCurrent, currentChanged})`, `kLiveMapMinZoom = 3.0`, `kLiveMapMaxZoom = 19.0`.
`routeBounds(points)` keeps its name/role but **changes return type** from `flutter_map`'s `LatLngBounds` to maplibre's `LngLatBounds` (feeds `controller.fitBounds` directly). `live_map_fit_test.dart` updates its type references; the three assertions (null-for-empty, encloses-every-point, single-point degenerate) are preserved in meaning.

## B. Renderer (the swap) — `lib/map/live_map.dart`
Replace the `FlutterMap(... TileLayer/PolylineLayer/MarkerLayer ...)` build with a `MapLibreMap`:

- **Options:** `initStyle: liveMapStyleUrl(dark)`, `initCenter: Position(lng, lat)` of `_center`, `initZoom: widget.initialZoom`, `minZoom: kLiveMapMinZoom`, `maxZoom: kLiveMapMaxZoom`, `androidTextureMode: false`, `androidMode: AndroidPlatformViewMode.hc`. (Spike-verified Android config; `hc` = Hybrid Composition, smoothest for a continuously-animating native view.)
- **Style per brightness:** rebuild the map with a `ValueKey(dark)` (no runtime `setStyle` in plugin 0.2.2) so a light↔dark theme switch reloads `topo-v2`/`basic-v2-dark`. Re-add route/markers in `onStyleLoaded` (fires again on reload).
- **Route line** (`onStyleLoaded`): one `GeoJsonSource(id:'route', data: routeLineGeoJson(points))` feeding two `LineStyleLayer`s — white halo `line-width 8` under blue `line-width 4.5` (`routeLineHalo`/`routeLineBlue` tokens), `line-cap/line-join: round` (matches the design + preview). Source `maxZoom` left at default — lowering it only oversimplifies the recorded line; the spike showed source `maxZoom` doesn't drive the *basemap* stutter, and the dense-route-while-recording test ran smooth at default (so no reason to touch it).
- **Live updates:** push new fixes via `style.updateGeoJsonSource(id:'route', data: …)` (grow the line) — verified smooth on the dense-route recording sim. Do **not** rebuild the map per fix.
- **Markers:** start (green) and end (red) via `CircleStyleLayer` (`circle-radius 9`); current position via a third `CircleStyleLayer` — blue fill + white `circle-stroke-width 3` ring. Update the current-position source on each new fix (`updateGeoJsonSource`) rather than rebuilding the map.
- **Camera follow / recenter:** in `didUpdateWidget`, reuse `followCameraUpdate(...)` (unchanged); on a non-null decision call `controller.animateCamera(center: Position(...), zoom: resetZoom ? initialZoom : <current zoom>)`. (`MapController` from `onMapCreated`.)
- **fitBounds:** when `widget.fitBounds && points.isNotEmpty`, after style load call `controller.fitBounds(bounds: routeBounds(points)!, padding: EdgeInsets.all(24))`.
- **onGesture:** subscribe via `onEvent` (or map gesture callback) and fire `widget.onGesture?.call()` on a user-initiated move/zoom, so the screen drops follow and shows the recenter control. Must distinguish user gestures from programmatic camera moves (guard with a flag around `animateCamera`/`fitBounds`).
- **Attribution:** drop the explicit `RichAttributionWidget` — maplibre-native renders MapTiler/OSM attribution itself (as the original Android app relied on). Remove the `url_launcher` import from this file (still used by `navigation_launcher.dart`).

## C. Offline tiles (parity with the removed `BuiltInMapCachingProvider`) — VERIFY ON DEVICE, not assumed
maplibre-native keeps an **ambient cache** (SQLite) of viewed tiles. Configure it once at startup via `OfflineManager.setMaximumAmbientCacheSize(bytes: 256 * 1024 * 1024)`, intent matching the removed 256 MB / 7-day flutter_map cache.
**Do not treat this as settled parity.** We already hit exactly this class of bug with flutter_map (it wouldn't serve *stale* cached tiles offline until `overrideFreshAge` was set); maplibre-native's ambient cache may likewise revalidate-and-fail when offline. Two unknowns to close during implementation:
1. **Entry point** — how the `OfflineManager` instance is obtained in this plugin (check `lib/src/offline/`), and whether it must be called before/after the first map create.
2. **Actual offline behaviour** — airplane-mode mid-ride must be confirmed to still render previously-viewed tiles (not blank). If the ambient cache revalidates-and-fails like flutter_map did, find the maplibre equivalent of `overrideFreshAge` or fall back to an explicit offline region.
Recording itself continues regardless — GPS is local (Spec 5A). No bulk pre-download (MapTiler ToS).

## D. Testing strategy (the real work — native platform views don't render in widget tests)
A `MapLibreMap` is a native platform view: in `flutter test` it renders an empty placeholder and its `onMapCreated`/`onStyleLoaded` channels never fire. So the strategy moves from "assert rendered map internals" to "unit-test pure builders + smoke-test the widget."

1. **Stays green unchanged:** `live_map_follow_test.dart` (`followCameraUpdate`) — pure bools, no map types.
2. **Minor edit:** `live_map_fit_test.dart` — `routeBounds` now returns `LngLatBounds`; update type references, keep the three assertions.
3. **New pure units** (replace the flutter_map-internal assertions in `widgets_test.dart`):
   - `liveMapStyleUrl(bool dark)` → asserts `topo-v2` light / `basic-v2-dark` dark, key injected.
   - `routeLineGeoJson(points)` → valid GeoJSON `LineString`, lng/lat order, empty/short-route handling.
   - (zoom constants already covered by the consts; assert them directly.)
4. **Widget/screen tests** (`widgets_test.dart` LiveMap cases, `active_ride_screen_test.dart`, `history_dialogs_test.dart`): add an additive `@visibleForTesting` seam to `LiveMap` — `Widget Function(BuildContext)? debugMapBuilder` defaulting to the real `MapLibreMap`. Tests inject a stub (a keyed `SizedBox`) so screens build, `find.byType(LiveMap)` works, and no native channel is touched. This keeps every embedding screen test green without faking the platform view.

## E. Dependencies & platform setup
- **pubspec:** add `maplibre` (pin the spike version; evaluate 0.3.5 — it may expose `GeoJsonOptions`/perf fixes — as a follow-up, not a blocker). Remove `flutter_map`, `flutter_map_*` caching, and `latlong2` (all confined to `live_map.dart`). Keep `url_launcher` (used elsewhere).
- **Android:** `minSdk` already ≥21 (plugin needs 21). Hybrid Composition needs no manifest change.
- **iOS:** maplibre runs native (maplibre-native) — ensure the iOS deployment target meets the plugin's Podfile minimum; location Info.plist keys already added in Spec 5B. No Live Activity impact.
- **Config:** extend `MapConfig`/`MapStyle` with `vectorStyleId(bool dark)` → `topo-v2` / `basic-v2-dark` and `vectorStyleUrl(bool dark)` (`…/maps/{id}/style.json?key=`). Key still via `--dart-define=MAPTILER_KEY=…` (never committed). The existing raster `rasterUrlTemplate` stays — the **preview pipeline still uses raster `streets-v2`/`-dark` tiles** and is unchanged.

## Acceptance
- `flutter analyze` clean; `flutter test` green — pure follow/fit/style-url/geojson units + smoke/screen tests via the builder seam.
- `LiveMap`'s public constructor is unchanged; all existing call sites compile untouched.
- Preview thumbnails unaffected (still raster PNGs, no per-scroll work).
- **On-device (required before merge, both platforms per standing rule):**
  - **Long dense route while actively recording** — smooth pan + per-fix `updateGeoJsonSource` + follow. ✅ verified on Android (Pixel 7) in the spike; ⬜ iOS pending.
  - Android (Pixel ✅) **and** iOS (iPhone ⬜): smooth fractional zoom / world-fit / pan; route + dots crisp; light & dark styles load (`topo-v2` / `basic-v2-dark`); recenter + follow behave; hand-pan drops follow.
  - ⬜ Airplane mode mid-ride: previously-viewed tiles still render (ambient cache — see §C, must be verified, not assumed); recording continues; offline banner shows.
- Branch `phase/16-maplibre-live-map` (or fold the existing `spike/maplibre-live-map`); delete `lib/dev/maplibre_demo.dart` before merge.

## Out of scope / follow-ups
- **Heading-up rotation** (>1.5 m/s) — not in current `LiveMap`; a clean follow-up via `animateCamera(bearing:)`.
- **Plugin 0.3.5 upgrade** — may expose deeper GeoJSON tuning; evaluate separately.
- **Custom dark "topo" style** in MapTiler Cloud — if a terrain-matching dark is later wanted instead of `basic-v2-dark`.
- Preview pipeline, GPS engine, Live Activities — untouched.

## Risks
1. **Widget-test coverage shape changes** — mitigated by pure builders + the `debugMapBuilder` seam; net coverage of *logic* is preserved, only "does the native map draw" moves to device verification.
2. **`onGesture` user-vs-programmatic disambiguation** — needs a guard flag around programmatic camera moves so follow isn't dropped by our own `animateCamera`.
3. **iOS parity unverified** — spike was Android-only; iOS smoothness/style load must be confirmed on a real iPhone before merge (hard gate).
4. **Plugin maturity (0.2.2)** — no `GeoJsonOptions` (buffer/tolerance/synchronous-update) exposed; acceptable since the chosen light style already pans smoothly.
