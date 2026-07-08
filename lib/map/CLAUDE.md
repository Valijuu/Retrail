# Map & previews (the key improvement)

> Keep this file in sync with the actual code — update it as part of the same change whenever something documented here changes.

- **Live/active-ride map:** `flutter_map`, route drawn as halo (white, wider) + blue line on top; heading-up rotation when moving > 1.5 m/s; smooth follow; activity/start/end markers.
- **Ride previews (history & home):** rendered **once at ride-save** — fetch the basemap tiles for the route's framing (Web Mercator bounds, zoom capped at `MAX_PREVIEW_ZOOM = 16`), paint halo+blue polyline on top, export to a **disk-cached PNG** keyed by `rideId`. Lists show `Image.file(...)` → no tiles, no network, no GL during scroll.
- **Offline at save-time:** store a flat `RouteSketch` PNG (polyline over `MapTerrain`), mark stale, regenerate full-tile snapshot when back online. Evict the cached image on ride edit/delete.
- Port projection math verbatim with its tests: `lonXAtZoom`, `latYAtZoom`, `latYFrac`, `projectPoint`, `computeFraming`, zoom cap, degenerate-bbox handling.

## Offline behavior

GPS recording and ride saving are **fully local — no internet required**. Only map *tiles* need the network. In flight mode: recording continues, the route polyline still draws, an offline banner shows, the ride saves with a flat preview that regenerates later. `ConnectivityObserver` uses an active HTTP `generate_204` probe (NOT the OS "validated" flag, which some VPNs fake), polled every 10s + on network change.
