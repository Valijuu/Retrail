# Spec 19 — Map provider: MapTiler → OpenFreeMap

**Status:** DRAFT — for review. Decisions from the conversation on 2026-10-06, recorded in #58.
**Depends on:** Spec 7 (preview pipeline), Spec 12 (preview wiring), Spec 16 (MapLibre live map), #45 (`MapAttribution`).

## Goal

Retrail stops using MapTiler. MapTiler's free plan is non-commercial only (Cloud terms §1), and Retrail is to ship free first and get paid features later. **OpenFreeMap** replaces it: free, no API key, no request limit, commercial use allowed, OpenMapTiles schema, weekly OSM data.

The pre-rendered preview architecture stays: lists show a cached PNG, rendered once per ride and theme. Only the tile source of that one-time render changes, from raster PNG tiles to vector tiles drawn in Dart.

## Non-goals

- No change to the preview cache, its stale/retry logic, the offline sketch, framing/projection, route line or markers.
- No change to the live map's behaviour (camera, follow, layers, reference route). Only its style changes.
- No self-hosting of tiles. If OpenFreeMap goes away, the same schema and styles can be self-hosted or pointed at another OpenMapTiles host later.

## A. Styles

| Theme | Live map | Previews |
|---|---|---|
| Light | **Liberty** by URL `https://tiles.openfreemap.org/styles/liberty` | bundled copy `assets/map/liberty.json` |
| Dark | **Retrail Dark**, bundled `assets/map/retrail_dark.json` | same file |

- **Retrail Dark** is OpenFreeMap **Dark** recoloured, because the original is near black (RGB 10–35): parks and water are invisible. The background is the app's `DarkMapTerrain` (`#20292A`), so the map matches the offline sketch; parks/wood are dark green, water dark blue (`#1B3346`), buildings `DarkMapTerrainGrid` (`#2C3A3A`), roads graded greys (paths `#3C4A49` … motorway casing `#66716D`). A grass/meadow layer (`landcover` class `grass`) is added in park green; Dark has none, so open fields like Tempelhofer Feld stay grey otherwise. Label (`symbol`) text colours are lifted so they read on the new background. The final colours are tuned on the device (light + dark, live map + previews) and documented in `lib/core/theme/CLAUDE.md`.
- The live map takes a style **URL or JSON string** (`MapOptions.initStyle`: Android `Style.Builder.fromJson` for a string starting with `{`, iOS `styleJSON`). The bundled dark style is loaded once in `main()` (like the other async overrides) and handed in as a string. `liveMapStyleUrl(bool dark)` becomes `liveMapStyle(bool dark)`.
- Liberty stays a URL on the live map so it picks up OpenFreeMap's fixes and its sprite/glyph versions. The previews use a bundled copy because they only need paint colours (no sprites, no glyphs: labels use the device font) and a fixed style keeps previews stable.
- **Licence:** the OpenFreeMap styles are MIT; their design is CC BY 4.0 from OpenMapTiles (Liberty ← OSM Liberty ← OSM Bright; Dark ← OpenMapTiles). The "© OpenMapTiles" credit covers it. Each bundled file keeps a `"metadata"` note of its origin.

## B. Preview tiles — `OpenFreeMapTileProvider`

A new `lib/map/openfreemap_tile_provider.dart` implements the existing seam `PreviewTileProvider` (`lib/map/preview_snapshot.dart`) and replaces `MapTilerTileProvider`. `renderPreviewPng` stays unchanged: it still gets one image per 256 dp grid tile.

1. **Tile URL.** `GET https://tiles.openfreemap.org/planet` (TileJSON) → `tiles[0]`, a versioned template like `…/planet/20260927_080001_pt/{z}/{x}/{y}.pbf`, and `maxzoom` (14). It is resolved once per process. A failed resolve yields no tiles (preview incomplete → stale → retried). A tile 404 drops the cached template (the weekly data version moved on), so the next tile resolves it again.
2. **Overzoom.** Previews go up to z16 (`maxPreviewZoom`), the data only to z14. A tile at z > 14 is drawn from its z14 parent: `dz = z − 14`, parent `(x >> dz, y >> dz)`, sub-square `(x mod 2^dz, y mod 2^dz)` of size `256 / 2^dz` within it, scaled by `2^dz`. Layer filtering uses the real `z`. Vector data stays sharp (probe: z16 crisp).
3. **Fetch.** `http` with an 8 s timeout per request (as today) and a `User-Agent: Retrail (io.github.valijuu.retrail)`. OpenFreeMap rejects some agents (Python's default got 403); the app identifies itself, as is fair towards a free service.
4. **Parse off the UI isolate.** pbf → `VectorTile` in `Isolate.run`. Only `TileFactory.createTileData(…).toTile()` and painting run on the UI isolate.
5. **Paint.** `vector_tile_renderer` (6.1.0) `Renderer` paints the tile with the **preview theme** onto a canvas at `previewPixelRatio` (3 → a 768 px image). The preview theme is the bundled style minus `raster` (Natural Earth shading, z ≤ 6) and `fill-extrusion` (3D buildings). **Labels stay** (decision 2026-10-06: like the MapTiler previews; drop them only if they turn out too slow). Icons are skipped (no sprite atlas).
6. **Cache.** An in-memory LRU of parsed tiles keyed by `(style, z14 parent)`, about 24 entries. Rides in the same area share tiles, so a catch-up after the cache version bump fetches and parses each tile once.
7. **Failure** of any step → `null` for that tile, as today (terrain hole, preview marked stale, retried later).

`_cacheVersion` 6 → 7 (`lib/map/route_preview_cache.dart`), so every preview re-renders with the new map.

### Measured (probe, 2026-10-06, Pixel 7, profile build, 4 dense Berlin z14 tiles)

| | without labels | with labels |
|---|---|---|
| UI-isolate painting (4 tiles) | 45–85 ms | 55–99 ms |
| Whole preview incl. parse + raster + PNG (after warm-up) | 170–270 ms | (raster measured at 1536², not comparable) |

Per tile that is roughly 10–25 ms on the UI isolate. A catch-up of ~100 previews (50 rides × 2 themes) takes about 20–30 s in the background, less with shared tiles. `maxConcurrentRenders` stays 3 unless jank shows on the device; then 1 during the catch-up.

## C. Credit — `MapAttribution`

- Text: **"© OpenMapTiles"** (→ `https://openmaptiles.org/`) and **"© OpenStreetMap"** (→ `https://www.openstreetmap.org/copyright`), same in EN and DE. The short OSM form is allowed by the OSMF Attribution Guidelines; naming OpenFreeMap is optional per OpenFreeMap. ARB: `mapAttributionOpenMapTiles`, `mapAttributionOsm` (new text); `mapAttributionMapTiler` is removed.
- **Live maps collapse it** (ride / follow map, detail and fullscreen map): it shows expanded, then collapses to a round ⓘ button after **5 s** or on the **first pointer-down outside the credit** (any touch counts as interacting with the screen; OSMF allows collapsing on map interaction or after 5 s). Tapping ⓘ expands it again; it collapses again on the next outside touch or after 5 s. The widget handles this itself (`collapsible: true`, a timer plus a global pointer route that ignores touches within its own box), so the hosts only pass the flag. The ⓘ is a small app-surface circle with `Icons.info_outline` in `onSurfaceVariant`, tooltip "Map credits" / "Kartenquellen".
- **Previews** keep the short text, not collapsible, not tappable (unchanged placement, bottom-left of the card).

## D. Removing MapTiler

All of it is dead once replaced:
- `lib/map/maptiler_tile_provider.dart` + test; `MapStyle` (`lib/map/map_style.dart`, MapTiler ids); `MapConfig.mapTilerKey`, `vectorStyleUrl`, `mapTilerCopyright`.
- The `MAPTILER_KEY` build define: `.github/workflows/ios-build.yml` (env + `--dart-define`), `maptiler.json` in `.gitignore`, `--dart-define-from-file=maptiler.json` in `docs/android-release.md`, `docs/ios-sideloading.md` (secret list, "the MapTiler key is compiled into every build"). The repo secret `MAPTILER_KEY` can be deleted afterwards (manual, GitHub settings). The `.ipa` stays encrypted (`IPA_PASSWORD`): the artifact is still downloadable by any signed-in user.
- Mentions in `CLAUDE.md` (tech stack "Tile source"), `lib/map/CLAUDE.md`, `lib/map/preview_projection.dart` (comment on `@2x` raster tiles).
- Older specs (7, 12, 15, 16) keep describing their time; this spec supersedes their MapTiler parts.

## E. Privacy policy

`site/privacy/index.html`, section 4 (DE + EN): the map service is **OpenFreeMap** (tiles via `tiles.openfreemap.org`, served through Cloudflare): IP address, user agent and the requested map area are transmitted; no account, no cookies (per OpenFreeMap). The link points to OpenFreeMap's terms/privacy page. "Last updated" moves to the merge date.

## F. Testing

- **Pure logic → EXACT (`tdd-dart`):** TileJSON → template; template → tile URL; overzoom (parent + sub-square + scale for z ≤ 14 and z 15/16); preview theme filter (drops `raster` and `fill-extrusion`, keeps `symbol`, keeps everything else in order).
- **Provider → Red-Green-Refactor** with a fake `http.Client` and a committed fixture pbf of a public place (a sparse z14 tile, OSM data under ODbL — no ride data): TileJSON fetched once; the tile URL and User-Agent sent; z16 fetches its z14 parent; two tiles of one parent → one fetch; 404 → `null` and the template re-resolved; timeout/garbage → `null`; a valid tile → a 768 px `ui.Image`.
- **Widgets → Red-Green-Refactor:** `MapAttribution` texts EN/DE and links; collapsible: collapses after 5 s (`fake_async`), on an outside pointer-down, not on a touch inside; ⓘ expands; non-collapsible previews unchanged. Hosts pass `collapsible: true` (ride map area, detail, fullscreen) and not on the cards.
- `live_map_style_test.dart`: light → the Liberty URL, dark → the bundled JSON string.
- **On the device (alongside, not test-first):** live map Liberty + Retrail Dark; previews re-render after the update in light + dark, with labels; no visible jank during the catch-up; offline → sketch, back online → map; the credit collapses and reopens; EN + DE.

## Acceptance

- `flutter analyze` clean, `flutter test` green.
- `grep -ri maptiler lib .github docs/android-release.md docs/ios-sideloading.md CLAUDE.md lib/map/CLAUDE.md` finds nothing; a release build needs no `--dart-define`.
- Device checks above pass on the Pixel 7; the iOS CI build is green.
- #58 closed, #45 updated.

## Risks

- **OpenFreeMap is run by one person on donations, without an SLA.** Mitigation: same schema and styles are self-hostable; the tile URL comes from TileJSON, so only the TileJSON URL and the Liberty URL would change.
- **Labels at tile edges** may be cut or doubled, because each tile is painted on its own. Cosmetic; checked on real previews. If it looks bad, drop labels (decision rule above).
- **Bundled Retrail Dark references OpenFreeMap's sprite/glyph URLs** (versioned). If OpenFreeMap retires a sprite version, the live dark map loses icons until the bundled style is updated. Check when updating the app.
