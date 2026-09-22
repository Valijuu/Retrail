# Map & previews (the key improvement)

> Keep this file in sync with the actual code — update it as part of the same change whenever something documented here changes.

- **Live/active-ride map:** native **MapLibre** (`maplibre` package) with a MapTiler *vector* style (`topo-v2` light / `basic-v2-dark` dark — topo-v2 has no dark twin). Route, start/end dots and the current-position marker are GeoJSON source layers: halo (white, wider) + blue line on top; the camera follows the current position and drops follow on a user gesture (recenter control reinstates it). No heading-up rotation — the camera stays north-up.
- **Android platform-view mode: texture-based** (`androidTextureMode: true`, `androidMode: AndroidPlatformViewMode.tlhc_vd` in `lib/map/live_map.dart`). Hybrid Composition (the smoother default for panning) rendered the map via its own independent native Surface; on a real device that surface could get recomposited mid-transition and flash a stale buffer from an unrelated earlier screen — reproduced as the countdown page flashing for one frame when leaving `/ride` (issue #11). Texture mode routes the map's output through Flutter's own frame instead, at some cost to pan/gesture smoothness. Revisit if that cost turns out to matter more than the flicker did.
- **Ride previews (history & home):** rendered **once at ride-save** — fetch MapTiler *raster* tiles (`@2x.png`, via `MaptilerTileProvider`) for the route's framing (Web Mercator bounds, zoom capped at `MAX_PREVIEW_ZOOM = 16`), paint halo+blue polyline on top, export to a **disk-cached PNG** keyed by `rideId`. Lists show `Image.file(...)` → no tiles, no network, no GL during scroll.
- **Offline at save-time:** store a flat `RouteSketch` PNG (polyline over `MapTerrain`), mark stale, regenerate full-tile snapshot when back online. Evict the cached image on ride edit/delete.
- Port projection math verbatim with its tests: `lonXAtZoom`, `latYAtZoom`, `latYFrac`, `projectPoint`, `computeFraming`, zoom cap, degenerate-bbox handling.

## Offline behavior

GPS recording and ride saving are **fully local — no internet required**. Only map *tiles* need the network. In flight mode: recording continues, the route polyline still draws, an offline banner shows, the ride saves with a flat preview that regenerates later. `ConnectivityObserver` uses an active HTTP `generate_204` probe (NOT the OS "validated" flag, which some VPNs fake), polled every 10s + on network change.
