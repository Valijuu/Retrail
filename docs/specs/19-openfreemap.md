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

| Theme | Live map and previews |
|---|---|
| Light | **Retrail Light**, bundled `assets/map/retrail_light.json` |
| Dark | **Retrail Dark**, bundled `assets/map/retrail_dark.json` |

- **Retrail Light** is OpenFreeMap **Liberty** in **MapTiler topo-v2's colours**, the map Retrail used before (decision 2026-10-06, after device rounds: Liberty's near-white ground glared; grey-green, cool grey and warm beige variants all looked off next to the orange position marker): ground `#EDEDED`, faint residential, outlined buildings `#CBC6BE`, olive green, teal water `#68A7C4`, dark grey footpaths, near-black street names. Buildings as in topo-v2: the flat `building` fill at every zoom (Liberty's `maxzoom: 14` removed — Liberty hands over to 3D there) with a **half-transparent** 3D layer on top from z14 (`#ABA59C` at 0.5 opacity). Liberty's opaque 3D walls cluttered the tracking view at zoom 16.5; flat-only was tried and the user wanted to see 3D again. Previews never draw 3D (`fill-extrusion` is dropped). Not reproducible: topo-v2's hillshade and contours (OpenFreeMap has no terrain data) and its Roboto font (OpenFreeMap serves Noto Sans only).
- **Retrail Dark** is OpenFreeMap **Dark** (near black, RGB 10–35, parks and water invisible) in **MapTiler basic-v2-dark's colours**, the previous dark map (decision 2026-10-06): neutral dark grey ground `#2B2B2B`, buildings a shade darker `#252525` with subtle 3D on top from z14 (an added half-transparent `#3A3A3A` extrusion, as in Retrail Light — Dark has none), very dark green `#252A1D` (also on an added `landcover` grass layer — Dark has none), water `#223949`, every road and path `#454545`, street names `#C2C2C2` on a soft 1.5 px `#1F1F1F` halo blurred 0.5 (the hard black 1 px halo looked jagged on the device), place labels `#DBDBDB`. Colours live in `tool/build_map_styles.dart` and `lib/core/theme/CLAUDE.md`.
- The live map takes a style URL, a JSON string or a **Flutter asset path** (`MapOptions.initStyle`; the `maplibre` package loads an asset itself on Android and iOS). The dark style is passed as its **asset path**: MapLibre loads it asynchronously like a URL. A JSON string would be applied synchronously, before `onMapCreated`, whose reset then discards it (no map at all — found on the device). `liveMapStyleUrl(bool dark)` becomes `liveMapStyle(bool dark)`.
- Both styles are bundled and used by the live map and the previews alike, so they look the same. The previews only use paint colours (no sprites, no glyphs: labels use the device font).
- **Licence:** the OpenFreeMap styles are MIT; their design is CC BY 4.0 from OpenMapTiles (Retrail Light ← Liberty ← OSM Liberty ← OSM Bright; Retrail Dark ← Dark ← OpenMapTiles). The "© OpenMapTiles" credit covers it. Each bundled file keeps a `"metadata"` note of its origin.

## B. Preview tiles — `OpenFreeMapTileProvider`

A new `lib/map/openfreemap_tile_provider.dart` implements the existing seam `PreviewTileProvider` (`lib/map/preview_snapshot.dart`) and replaces `MapTilerTileProvider`. `renderPreviewPng` stays unchanged: it still gets one image per 256 dp grid tile.

1. **Tile URL.** `GET https://tiles.openfreemap.org/planet` (TileJSON) → `tiles[0]`, a versioned template like `…/planet/20260927_080001_pt/{z}/{x}/{y}.pbf`, and `maxzoom` (14). It is resolved once per process. A failed resolve yields no tiles (preview incomplete → stale → retried). A tile 404 drops the cached template (the weekly data version moved on), so the next tile resolves it again.
2. **Overzoom.** Previews go up to z16 (`maxPreviewZoom`), the data only to z14. A tile at z > 14 is drawn from its z14 parent: `dz = z − 14`, parent `(x >> dz, y >> dz)`, sub-square `(x mod 2^dz, y mod 2^dz)` of size `256 / 2^dz` within it, scaled by `2^dz`. Layer filtering uses the real `z`. Vector data stays sharp (probe: z16 crisp).
3. **Fetch.** `http` with an 8 s timeout per request (as today) and a `User-Agent: Retrail (io.github.valijuu.retrail)`. OpenFreeMap rejects some agents (Python's default got 403); the app identifies itself, as is fair towards a free service.
4. **Parse off the UI isolate.** pbf → `VectorTile` in `Isolate.run`. Only `TileFactory.createTileData(…).toTile()` and painting run on the UI isolate.
5. **Paint.** `vector_tile_renderer` (6.1.0) `Renderer` paints the tile with the **preview theme**, labels laid out at `kPreviewLabelScale` (0.65) of the style's size (street names crowded the small preview), evaluated **one zoom level below** the grid tile's zoom (`kPreviewStyleZoomOffset`: MapLibre styles assume 512 px tiles, the grid uses 256 dp ones; at the grid zoom roads and labels came out a level too big — seen on the device), onto a canvas at `previewPixelRatio` (3 → a 768 px image). The preview theme is the bundled style minus `raster` (Natural Earth shading, z ≤ 6) and `fill-extrusion` (3D buildings). **Labels stay** (decision 2026-10-06: like the MapTiler previews; drop them only if they turn out too slow). Icons are skipped (no sprite atlas).
6. **Cache.** An in-memory LRU of parsed tiles keyed by `(style, z14 parent)`, about 24 entries. Rides in the same area share tiles, so a catch-up after the cache version bump fetches and parses each tile once.
7. **Failure** of any step → `null` for that tile, as today (terrain hole, preview marked stale, retried later).

`_cacheVersion` 6 → 10 over the device rounds (`lib/map/route_preview_cache.dart`), so every preview re-renders with the new map. `renderPreviewPng` snaps each tile to whole device pixels, so the 768 px tile lands 1:1 instead of being resampled between pixels (blurred previews, seen on the device).

### Measured (probe, 2026-10-06, Pixel 7, profile build, 4 dense Berlin z14 tiles)

| | without labels | with labels |
|---|---|---|
| UI-isolate painting (4 tiles) | 45–85 ms | 55–99 ms |
| Whole preview incl. parse + raster + PNG (after warm-up) | 170–270 ms | (raster measured at 1536², not comparable) |

Per tile that is roughly 10–25 ms on the UI isolate. A catch-up of ~100 previews (50 rides × 2 themes) takes about 20–30 s in the background, less with shared tiles. `maxConcurrentRenders` stays 3 unless jank shows on the device; then 1 during the catch-up.

## C. Credit — `MapAttribution`

- Text: **"© OpenMapTiles"** (→ `https://openmaptiles.org/`) and **"© OpenStreetMap"** (→ `https://www.openstreetmap.org/copyright`), same in EN and DE. The short OSM form is allowed by the OSMF Attribution Guidelines; naming OpenFreeMap is optional per OpenFreeMap. ARB: `mapAttributionOpenMapTiles`, `mapAttributionOsm` (new text); `mapAttributionMapTiler` is removed.
- **It always stays written out** on every map (decision 2026-10-06, after trying it on the device: the collapse to ⓘ was dropped). Bottom centre of the ride / follow map and of the detail and fullscreen map, tappable.
- **Previews** show the same short text, not tappable (bottom-left of the card).

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
- **Widgets → Red-Green-Refactor:** `MapAttribution` texts EN/DE and links and that it stays written out past 5 s.
- `live_map_style_test.dart`: light → the Liberty URL, dark → the bundled asset path.
- **On the device (alongside, not test-first):** live map Liberty + Retrail Dark; previews re-render after the update in light + dark, with labels; no visible jank during the catch-up; offline → sketch, back online → map; the credit stays written out; EN + DE.

## Acceptance

- `flutter analyze` clean, `flutter test` green.
- `grep -ri maptiler lib .github docs/android-release.md docs/ios-sideloading.md CLAUDE.md lib/map/CLAUDE.md` finds nothing; a release build needs no `--dart-define`.
- Device checks above pass on the Pixel 7; the iOS CI build is green.
- #58 closed, #45 updated.

## Risks

- **OpenFreeMap is run by one person on donations, without an SLA.** Mitigation: same schema and styles are self-hostable; the tile URL comes from TileJSON, so only the TileJSON URL and the Liberty URL would change.
- **Labels at tile edges** may be cut or doubled, because each tile is painted on its own. Cosmetic; checked on real previews. If it looks bad, drop labels (decision rule above).
- **Bundled Retrail Dark references OpenFreeMap's sprite/glyph URLs** (versioned). If OpenFreeMap retires a sprite version, the live dark map loses icons until the bundled style is updated. Check when updating the app.
