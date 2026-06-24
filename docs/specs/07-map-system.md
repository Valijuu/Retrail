# Spec 7 — Map System (preview snapshots + live map)

**Status:** awaiting review
**Phase:** 7 of 15
**Depends on:** Spec 2 (tokens), Spec 4 (none directly), Spec 5A (`ConnectivityObserver` for offline fallback)

## Goal
Deliver the headline change: **ride-preview thumbnails rendered once at save and cached as PNGs** (no per-scroll tiles), plus the **live/active-ride map**. Port the projection math verbatim with its 8 tests. The preview pipeline's math/cache logic is unit-tested; the live map widget is built here but fully verified on-device later.

## A. Preview snapshot pipeline (the core fix)

### A1. Projection math — `lib/map/preview_projection.dart` (port verbatim)
Pure Dart, ported 1:1 from the original `StaticRouteMap`:
- `const double maxPreviewZoom = 16.0`
- `StaticFraming { double centerLat, centerLon, zoom; int widthDp, heightDp }`
- `StaticFraming computeFraming(List<RoutePoint> points, int widthDp, int heightDp)` — bbox center; `padDp=16`; degenerate bbox (`lonFrac<1e-7 && latFrac<1e-7`) → `maxPreviewZoom`; else `floor(min(zoomLon, zoomLat)).clamp(1.0, maxPreviewZoom)` via `log2`.
- `double latYFrac(double lat)`, `double lonXAtZoom(lon, zoom)`, `double latYAtZoom(lat, zoom)`
- `Offset projectPoint(RoutePoint p, StaticFraming f)` (use `ui.Offset`/a small record `(double x, double y)` to stay Flutter-light).

**Port `StaticRouteMapTest` (8 cases):** tiny-span ride caps at z16; single point → z16; normal ride < z16 and ≥1; bbox center → slot center (±0.5); eastern point right of western; northern point above southern (smaller y); all points inside slot; Web Mercator anchors (`lonXAtZoom(-180,0)=0`, `(0,0)=128`, `(180,0)=256`, `latYAtZoom(0,0)=128`, `latYAtZoom(45,0)<128`).

### A2. Tile grid — `lib/map/tile_grid.dart` (port `TileBackdrop` math)
`List<TileRef> tilesFor(StaticFraming f)` where `TileRef { int z, x, y; double offsetXDp, offsetYDp }`:
- `z = f.zoom.toInt()`; `left = lonXAtZoom(centerLon,z) - widthDp/2`, `right = +widthDp/2`, `top = latYAtZoom(centerLat,z) - heightDp/2`, `bottom = +heightDp/2`.
- `txMin..txMax = floor(left/256)..floor(right/256)`, `ty` likewise; `tilesPerAxis = 2^z`; wrap x (`((tx % n)+n)%n`), skip y out of `[0, n)`.
- `offset = (t*256 - left/top)`. (256-dp tile slots; the raster PNG scales in.)
- **Tests:** known framing → expected tile count + offsets; x-wrap at the antimeridian; y-clamp near poles.

### A3. Snapshot renderer — `lib/map/preview_snapshot.dart`
`Future<Uint8List> renderPreviewPng({required List<RoutePoint> points, required int widthDp, required int heightDp, required double pixelRatio, required TileProvider tiles, required Brightness brightness})`:
- Compute framing + tile grid; fetch each tile via `TileProvider` (interface; real impl = MapTiler `/{mapId}/{z}/{x}/{y}.png?key=…`, `streets-v2`/`streets-v2-dark`); composite onto a `Canvas` (`PictureRecorder`) at the dp offsets × `pixelRatio`.
- Draw the route with `projectPoint`: **halo 6dp (white) then blue 3.5dp** (`RouteLineHalo`/`RouteLineBlue` tokens), round cap/join; start/end dots.
- Export `picture.toImage(...).toByteData(png)`.
- `TileProvider` is injectable so tests use fake solid-color tiles (deterministic, no network).

### A4. Preview cache — `lib/map/route_preview_cache.dart`
- File per ride: `<cacheDir>/ride_previews/<rideId>.png`.
- `Future<File> ensurePreview(rideId, points, …)` — generate once if missing; return the file. Generation runs at ride-save (Spec 12) and lazily on first view.
- **Offline fallback:** if `ConnectivityObserver` reports offline at generation time, render the flat `RouteSketch` PNG (polyline over `MapTerrain`, no tiles) and mark it stale; regenerate the full-tile snapshot when back online.
- `evict(rideId)` — delete file + `FileImage(...).evict()` on ride edit/delete (covers route changes).
- **Tests:** path keyed by rideId; ensurePreview generates once (second call reuses); evict removes file; offline path uses the flat renderer.

### A5. `RoutePreview` widget — `lib/map/route_preview.dart`
`Image.file(previewFile, cacheWidth: …, fit: cover)` with a placeholder while generating. Used by history/home cards — **zero tiles/network during scroll**.

### A6. `RouteSketch` — `lib/map/route_sketch.dart`
Pure `CustomPainter` fallback: proportional-scale points into the slot, halo+blue line + endpoints over a `MapTerrain` background. Also the live-map empty/no-tiles fallback. Testable via golden + projection-into-bounds asserts.

## B. Live / active-ride map — `lib/map/live_map.dart` (`flutter_map`)
- Add deps: `flutter_map_tile_caching` (FMTC) for tile caching (deferred from Spec 1).
- MapTiler raster tiles (`streets-v2`/`-dark`) via FMTC; attribution shown.
- Route polyline: **halo 8dp + blue 4.5dp** (live widths); start (green) / end (red) / live activity marker.
- Heading-up rotation when moving > 1.5 m/s; smooth follow; recenter control.
- Consumes `RideTracker` state (Spec 5A) for the live route + position.
- **Verification:** builds + widget-tests for static rendering; rotation/follow feel validated on-device later (raster `flutter_map` vs the original vector map — fall back to a native MapLibre Flutter plugin for the live screen only if it's too jerky; previews are unaffected, they're static PNGs).

## Config
- `MapStyle.mapId(bool dark)` → `streets-v2` / `streets-v2-dark`.
- **MapTiler key** via `--dart-define=MAPTILER_KEY=…` (not committed); reuse the existing key. A `lib/map/map_config.dart` reads it.

## Acceptance
- `flutter analyze` clean; `flutter test` green — projection (8 ported), tile-grid, cache, snapshot-with-fake-tiles, RouteSketch golden.
- Preview PNG generates once and renders via `Image.file` (no per-scroll work).
- Live map builds and renders a route in a widget test.
- Branch `phase/07-map-system` rebased + fast-forwarded onto `main`, then deleted.

## Out of scope
History/home card layouts (Specs 10/13 — they embed `RoutePreview`), the active-ride screen chrome (Spec 12 — embeds `LiveMap`), GPS Part B.
