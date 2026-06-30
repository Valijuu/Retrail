# Implementation Plan — Spec 16: Live map `flutter_map` → native MapLibre

**Spec:** `docs/specs/16-maplibre-live-map.md` (approved)
**Branch:** continue on `spike/maplibre-live-map` (fold the spike) — rename intent `phase/16-maplibre-live-map`.
**Date:** 2026-06-30

## How to use this plan

Each task is bite-sized and test-first. Within a task: write the failing test (RED), implement
the minimum to pass (GREEN), then run the gate. **Gate after every task:** `flutter analyze` clean
AND `flutter test` green. Do not start the next task until the gate passes. No placeholders, no
`TODO`s left in code.

The MapTiler key is supplied at build/test time via `--dart-define=MAPTILER_KEY=…` and is **never
committed**. Tests run with the key absent (`String.fromEnvironment` default `''`), so assertions
must not depend on a real key value — only on URL structure / style id.

### Verified API facts (maplibre 0.2.2) this plan relies on

- `MapLibreMap({key, required options, onMapCreated, onStyleLoaded, onEvent})`.
  - `onMapCreated: void Function(MapController)`, `onStyleLoaded: void Function(StyleController)`,
    `onEvent: void Function(MapEvent)`.
- `MapOptions({initStyle, initCenter: Position(lng,lat), initZoom, minZoom, maxZoom, androidTextureMode, androidMode})`.
- `MapController`: `Future<void> animateCamera({Position? center, double? zoom, …, Duration nativeDuration})`,
  `Future<void> fitBounds({required LngLatBounds bounds, …, EdgeInsets padding})`,
  `MapCamera? get camera` (sync; `camera?.zoom`).
- `StyleController`: `addSource(GeoJsonSource(id, data))`, `addLayer(LineStyleLayer/CircleStyleLayer)`,
  `updateGeoJsonSource(id:, data:)`.
- **Gesture detection (no guard flag needed):** `onEvent` emits `MapEventStartMoveCamera(reason:)`.
  `CameraChangeReason` ∈ {`developerAnimation`, `apiAnimation`, `apiGesture`}. Fire `onGesture`
  **only** when `event is MapEventStartMoveCamera && event.reason == CameraChangeReason.apiGesture`.
  Our own `animateCamera`/`fitBounds` report `developerAnimation`/`apiAnimation`, so follow is never
  dropped by programmatic moves. (This supersedes Spec 16 §B/Risk 2's "guard flag" approach.)
- `LngLatBounds({longitudeWest, longitudeEast, latitudeSouth, latitudeNorth})` and
  `LngLatBounds.fromPoints(List<Position>)`. **No `contains()` method** — fit tests assert the four
  edge fields enclose each point.
- `Position(lng, lat)` — GeoJSON order (lng first).
- `OfflineManager.createInstance() → Future<OfflineManager>`; `Future<void> setMaximumAmbientCacheSize({required int bytes})`.

---

## Task 1 — `MapConfig` vector style + `liveMapStyleUrl` pure unit

**Files:** `lib/map/map_config.dart`, `lib/map/live_map.dart`, `test/map/live_map_style_test.dart` (new).

**RED** — `test/map/live_map_style_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/map/live_map.dart';

void main() {
  group('liveMapStyleUrl', () {
    test('light mode uses topo-v2', () {
      final url = liveMapStyleUrl(false);
      expect(url, contains('/maps/topo-v2/style.json'));
      expect(url, contains('key=')); // key injected (empty in tests, never committed)
    });
    test('dark mode uses basic-v2-dark (topo has no dark twin)', () {
      expect(liveMapStyleUrl(true), contains('/maps/basic-v2-dark/style.json'));
    });
  });
}
```

**GREEN:**
- In `MapConfig`, **keep** `rasterUrlTemplate` (preview pipeline still uses raster `streets-v2`), add:
  ```dart
  /// Vector style id for the live map. topo-v2 has no dark twin, so dark mode
  /// pairs with the lighter basic-v2-dark (both verified smooth on-device).
  static String vectorStyleId(bool dark) => dark ? 'basic-v2-dark' : 'topo-v2';

  /// MapLibre vector style document URL for the live map.
  static String vectorStyleUrl(bool dark) =>
      'https://api.maptiler.com/maps/${vectorStyleId(dark)}/style.json?key=$mapTilerKey';
  ```
- In `live_map.dart`, add the tested top-level pure unit (Spec 16 §D.3):
  ```dart
  /// Live-map MapLibre style URL for the current brightness. Pure, so the
  /// style choice is unit-tested without a real key or a rendered map.
  String liveMapStyleUrl(bool dark) => MapConfig.vectorStyleUrl(dark);
  ```

**Gate:** analyze + test.

---

## Task 2 — `routeLineGeoJson` + point GeoJSON pure units

**Files:** `lib/map/live_map.dart`, `test/map/live_map_geojson_test.dart` (new).

**RED** — `test/map/live_map_geojson_test.dart`:
```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/map/live_map.dart';
import 'package:retrail/map/preview_projection.dart';

void main() {
  group('routeLineGeoJson', () {
    test('emits a LineString in lng,lat order', () {
      const pts = <RoutePoint>[(lat: 49.44, lng: 11.08), (lat: 49.45, lng: 11.10)];
      final f = jsonDecode(routeLineGeoJson(pts)) as Map<String, dynamic>;
      expect(f['type'], 'Feature');
      expect(f['geometry']['type'], 'LineString');
      final coords = f['geometry']['coordinates'] as List;
      expect(coords.first, [11.08, 49.44]); // [lng, lat]
      expect(coords.length, 2);
    });
    test('an empty route yields a valid feature with no coordinates', () {
      final f = jsonDecode(routeLineGeoJson(const [])) as Map<String, dynamic>;
      expect(f['geometry']['coordinates'], isEmpty);
    });
  });
}
```

**GREEN** — in `live_map.dart`:
```dart
/// GeoJSON LineString feature for the recorded route (lng,lat order). Pure, so
/// the geometry that feeds the MapLibre source is unit-tested without a map.
String routeLineGeoJson(List<RoutePoint> points) => jsonEncode({
      'type': 'Feature',
      'geometry': {
        'type': 'LineString',
        'coordinates': [for (final p in points) [p.lng, p.lat]],
      },
      'properties': <String, Object?>{},
    });

String _pointGeoJson(RoutePoint p) => jsonEncode({
      'type': 'Feature',
      'geometry': {'type': 'Point', 'coordinates': [p.lng, p.lat]},
      'properties': <String, Object?>{},
    });
```
(Add `import 'dart:convert';`.)

**Gate:** analyze + test.

---

## Task 3 — `routeBounds` → `LngLatBounds`; update fit test

**Files:** `lib/map/live_map.dart`, `test/map/live_map_fit_test.dart`.

**RED** — rewrite `test/map/live_map_fit_test.dart` (LngLatBounds has no `contains`; assert edges).
Drop the `latlong2` import:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/map/live_map.dart';
import 'package:retrail/map/preview_projection.dart';

bool _encloses(b, RoutePoint p) =>
    p.lng >= b.longitudeWest && p.lng <= b.longitudeEast &&
    p.lat >= b.latitudeSouth && p.lat <= b.latitudeNorth;

void main() {
  group('routeBounds', () {
    test('null for an empty route (nothing to fit)', () {
      expect(routeBounds(const []), isNull);
    });
    test('encloses every point of the route', () {
      const points = <RoutePoint>[
        (lat: 49.40, lng: 11.05),
        (lat: 49.46, lng: 11.12),
        (lat: 49.42, lng: 11.02),
        (lat: 49.47, lng: 11.09),
      ];
      final b = routeBounds(points)!;
      for (final p in points) {
        expect(_encloses(b, p), isTrue, reason: 'point ($p) must be inside the fitted bounds');
      }
    });
    test('a single point yields a degenerate but valid bounds', () {
      final b = routeBounds(const [(lat: 49.4, lng: 11.0)])!;
      expect(_encloses(b, const (lat: 49.4, lng: 11.0)), isTrue);
    });
  });
}
```

**GREEN** — in `live_map.dart`, change `routeBounds` (still imports flutter_map for `build()` until Task 4):
```dart
/// Bounding box enclosing every point of [points], or null when empty. Feeds
/// MapLibre's controller.fitBounds directly. Pure, unit-tested without a map.
LngLatBounds? routeBounds(List<RoutePoint> points) {
  if (points.isEmpty) return null;
  return LngLatBounds.fromPoints([for (final p in points) Position(p.lng, p.lat)]);
}
```
Add `import 'package:maplibre/maplibre.dart';`. Note: `build()` still references flutter_map's
`CameraFit`/`LatLng` at this point — that's removed in Task 4. If analyze flags a transient type
clash, proceed to Task 4 immediately (these two tasks land together for a green file). **Recommended:
do Task 3 and Task 4 as one commit** so the file never compiles against both bounds types.

**Gate:** analyze + test (after Task 4 lands).

---

## Task 4 — Swap the renderer to `MapLibreMap` (+ `debugMapBuilder` seam, gesture, follow, fit, live updates)

**File:** `lib/map/live_map.dart` (the core change). Land together with Task 3.

This rewrites only `_LiveMapState`. The public constructor is **unchanged** — the test seam is a
**static** override, not a constructor param (see the empirical finding below).

> **EMPIRICAL FINDING (settled, do not re-litigate):** A real `MapLibreMap` does **not** render inert
> under `flutter test` — its `createState()` throws `UnimplementedError: Unsupported platform`
> synchronously (maplibre 0.2.2 `platform_native.dart:16`: `if (Platform.isAndroid) … else throw`).
> The host test VM is neither Android nor web, so **every** test that builds a real LiveMap crashes —
> including the two that construct it via an embedder (`RideDetailDialog`, `_ActiveRideMap`) and so
> cannot receive a per-instance builder. Channel-mocking does **not** help (it's a hard Dart `throw`,
> not a method channel). Therefore the seam is a **static** `LiveMap.debugMapBuilderOverride` that the
> `build()` consults — it reaches embedder-constructed maps too, needs **zero** change to
> `RideDetailDialog`/`active_ride_screen`, and stays inside the one widget being swapped. Mirrors
> Flutter's own `debugDefaultTargetPlatformOverride` pattern (set in `setUp`, cleared in `tearDown`).
>
> Side note for the iOS device gate (not a test concern): maplibre 0.2.2's `PlatformImpl` only branches
> on `Platform.isAndroid` — confirm the pinned version actually implements iOS, or bump it, before the
> iOS verification.

**Static test seam (top of `LiveMap`):**
```dart
/// Test seam: when non-null, every [LiveMap] (built directly OR inside a screen)
/// renders this instead of the native [MapLibreMap]. The native map throws
/// `UnimplementedError` under `flutter test`, so screen/widget tests set this in
/// `setUp` and clear it in `tearDown`. Null in production → real map.
@visibleForTesting
static Widget Function(BuildContext context)? debugMapBuilderOverride;
```

**State rewrite (`_LiveMapState`):**
- Remove: `MapController _controller = MapController()` (flutter_map), `_tileProvider`,
  `_center`'s `LatLng`, the whole `FlutterMap(...)` tree, the flutter_map/latlong2/url_launcher imports.
- Fields:
  ```dart
  MapController? _controller;
  StyleController? _style;
  ```
- `didUpdateWidget`: keep the `followCameraUpdate(...)` call (unchanged signature). On a non-null
  decision, **and** push live source updates:
  ```dart
  @override
  void didUpdateWidget(LiveMap old) {
    super.didUpdateWidget(old);
    if (widget.points != old.points) {
      _style?.updateGeoJsonSource(id: 'route', data: routeLineGeoJson(widget.points));
    }
    if (widget.current != old.current && widget.current != null) {
      _style?.updateGeoJsonSource(id: 'current', data: _pointGeoJson(widget.current!));
    }
    final d = followCameraUpdate(
      wasFollowing: old.isFollowing,
      isFollowing: widget.isFollowing,
      hasCurrent: widget.current != null,
      currentChanged: widget.current != old.current,
    );
    if (d != null) {
      final c = _centerPosition;
      _controller?.animateCamera(
        center: c,
        zoom: d.resetZoom ? widget.initialZoom : (_controller?.camera?.zoom ?? widget.initialZoom),
        nativeDuration: const Duration(milliseconds: 600),
      );
    }
  }

  Position get _centerPosition {
    final c = widget.current ?? (widget.points.isNotEmpty ? widget.points.last : null);
    return c != null ? Position(c.lng, c.lat) : Position(0, 0);
  }
  ```
- `build`:
  ```dart
  @override
  Widget build(BuildContext context) {
    final override = LiveMap.debugMapBuilderOverride;
    if (override != null) return override(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return MapLibreMap(
      // Rebuild on brightness change to reload topo-v2/basic-v2-dark (no runtime setStyle in 0.2.2).
      key: ValueKey(dark),
      options: MapOptions(
        initStyle: liveMapStyleUrl(dark),
        initCenter: _centerPosition,
        initZoom: widget.initialZoom,
        minZoom: kLiveMapMinZoom,
        maxZoom: kLiveMapMaxZoom,
        androidTextureMode: false,                     // native SurfaceView (texture mode = perf penalty)
        androidMode: AndroidPlatformViewMode.hc,       // Hybrid Composition (smoothest animating native view)
      ),
      onMapCreated: (c) => _controller = c,
      onStyleLoaded: _onStyleLoaded,
      onEvent: (e) {
        // Drop follow only on a real user gesture — programmatic moves report
        // developerAnimation/apiAnimation, so our own camera animations don't trip this.
        if (e is MapEventStartMoveCamera && e.reason == CameraChangeReason.apiGesture) {
          widget.onGesture?.call();
        }
      },
    );
  }
  ```
- `_onStyleLoaded` (fires again after a brightness-driven reload — re-adds everything):
  ```dart
  Future<void> _onStyleLoaded(StyleController style) async {
    _style = style;
    final colors = Theme.of(context).extension<AppColors>()!;
    final halo = '#${(colors.routeLineHalo.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final blue = '#${(colors.routeLineBlue.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final green = '#${(colors.markerStartGreen.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final red = '#${(colors.markerEndRed.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

    await style.addSource(GeoJsonSource(id: 'route', data: routeLineGeoJson(widget.points)));
    await style.addLayer(LineStyleLayer(
      id: 'route-halo', sourceId: 'route',
      layout: const {'line-cap': 'round', 'line-join': 'round'},
      paint: {'line-color': halo, 'line-width': 8.0}));
    await style.addLayer(LineStyleLayer(
      id: 'route-line', sourceId: 'route',
      layout: const {'line-cap': 'round', 'line-join': 'round'},
      paint: {'line-color': blue, 'line-width': 4.5}));

    if (widget.points.isNotEmpty) {
      await style.addSource(GeoJsonSource(id: 'start', data: _pointGeoJson(widget.points.first)));
      await style.addLayer(CircleStyleLayer(id: 'start-dot', sourceId: 'start',
        paint: {'circle-radius': 9.0, 'circle-color': green,
                'circle-stroke-width': 2.0, 'circle-stroke-color': '#FFFFFF'}));
    }
    if (widget.points.length >= 2) {
      await style.addSource(GeoJsonSource(id: 'end', data: _pointGeoJson(widget.points.last)));
      await style.addLayer(CircleStyleLayer(id: 'end-dot', sourceId: 'end',
        paint: {'circle-radius': 9.0, 'circle-color': red,
                'circle-stroke-width': 2.0, 'circle-stroke-color': '#FFFFFF'}));
    }
    // Current-position dot (blue + white ring), updated per fix via updateGeoJsonSource.
    final cur = widget.current;
    await style.addSource(GeoJsonSource(
      id: 'current',
      data: cur != null ? _pointGeoJson(cur) : '{"type":"FeatureCollection","features":[]}'));
    await style.addLayer(CircleStyleLayer(id: 'current-dot', sourceId: 'current',
      paint: {'circle-radius': 7.0, 'circle-color': blue,
              'circle-stroke-width': 3.0, 'circle-stroke-color': '#FFFFFF'}));

    if (widget.fitBounds && widget.points.isNotEmpty) {
      await _controller?.fitBounds(
        bounds: routeBounds(widget.points)!,
        padding: const EdgeInsets.all(24));
    }
  }
  ```
  > **Verify during implementation:** the exact hex-conversion helper for the `AppColors` tokens
  > (`Color` → `#RRGGBB`). Confirm `toARGB32()` exists in the project's Flutter SDK; if not, use the
  > `.r/.g/.b` (0–1 doubles ×255) accessors. Pick one, factor a single `_hex(Color)` helper, and use
  > it for all five colors. Do not leave two approaches in the file.
- Remove the old `_dot` Marker helper and the `RichAttributionWidget` (maplibre-native draws MapTiler/OSM
  attribution itself, as the original Android app relied on).

**Gate:** analyze + test (with the seam, embedding-screen tests don't touch the native channel; Task 5
fixes the now-broken `widgets_test.dart` LiveMap cases).

---

## Task 5 — Update widget/screen tests to the static seam + pure units

**Files:** `test/map/widgets_test.dart`, `test/history/history_dialogs_test.dart`,
`test/active_ride/active_ride_screen_test.dart`.

**Blast radius (settled by grep):** exactly three files pump a real `LiveMap` — one directly
(`widgets_test.dart`), two via embedders (`history_dialogs_test.dart` → `RideDetailDialog`,
`active_ride_screen_test.dart` → `_ActiveRideMap`). All three crash on the native map unless the static
override is set. **No production embedder is touched** — the static seam handles all three.

**Shared test harness** — add to each of the three files (or a tiny shared `test/support/live_map_stub.dart`):
```dart
Widget _stubMap(BuildContext _) => const SizedBox(key: ValueKey('stub-map'));

void useStubLiveMap() {
  setUp(() => LiveMap.debugMapBuilderOverride = _stubMap);
  tearDown(() => LiveMap.debugMapBuilderOverride = null); // never leak across tests
}
```
Call `useStubLiveMap();` at the top of each `main()` (or the relevant `group`).

**`widgets_test.dart`:**
- Remove the `flutter_map` import and the three flutter_map-internal LiveMap assertions
  (`find.byType(FlutterMap)`, `options.backgroundColor/minZoom/maxZoom`, `TileLayer.panBuffer/tileProvider`)
  — those internals no longer exist.
- Keep the two `RoutePreview` tests unchanged (preview pipeline untouched).
- With the stub active, a smoke test:
  ```dart
  testWidgets('LiveMap builds (native map stubbed via static override)', (tester) async {
    const route = <RoutePoint>[(lat: 49.44, lng: 11.08), (lat: 49.45, lng: 11.10)];
    await tester.pumpWidget(_wrap(const SizedBox(
      width: 300, height: 300, child: LiveMap(points: route))));
    expect(find.byKey(const ValueKey('stub-map')), findsOneWidget);
  });
  ```
- Zoom-envelope coverage moves to asserting the consts directly (no map needed):
  ```dart
  test('live map zoom envelope', () {
    expect(kLiveMapMinZoom, 3.0);
    expect(kLiveMapMaxZoom, 19.0);
  });
  ```

**`history_dialogs_test.dart:128`** (`tester.widget<LiveMap>(...).fitBounds` is `true`): the assertion
reads the widget prop and is unchanged — but the test now needs `useStubLiveMap()` so the embedded
real map doesn't throw `UnimplementedError`. Add the harness call; assertion stays.

**`active_ride_screen_test.dart`:** add `useStubLiveMap()`. The screen already passes `onGesture`/
`isFollowing` to `LiveMap`; nothing else changes. Any existing assertions on recenter FAB / follow
behaviour keep working (they don't depend on the map body).

**Gate:** analyze + test (full suite green).

---

## Task 6 — pubspec: drop `flutter_map` + `latlong2`, keep `url_launcher`

**File:** `pubspec.yaml`.

- Remove `flutter_map`, any `flutter_map_*` caching package, and `latlong2`. Confirm no remaining
  imports: `grep -rn "flutter_map\|latlong2" lib test` returns nothing.
- **Keep** `url_launcher` (used by `navigation_launcher.dart`) and `maplibre` (already added by the spike).
- `flutter pub get`.

**Gate:** analyze + test. `grep` confirms zero residual references.

---

## Task 7 — Offline ambient cache config (parity intent; VERIFY ON DEVICE)

**File:** app bootstrap (`lib/main.dart` or the existing startup init).

- After `WidgetsFlutterBinding.ensureInitialized()`, configure the maplibre-native ambient cache once:
  ```dart
  // Match the removed 256 MB flutter_map tile cache so revisited tiles render offline.
  final offline = await OfflineManager.createInstance();
  await offline.setMaximumAmbientCacheSize(bytes: 256 * 1024 * 1024);
  offline.dispose(); // configuration persists in the native SQLite ambient cache
  ```
  Guard with `if (MapConfig.hasKey)` is unnecessary (cache size is key-independent), but wrap in a
  `try/catch` that logs and continues — a cache-config failure must never block app start.
- **No unit test** (no public hook; native-only). This task is wiring + manual device verification.
- **DEVICE VERIFY (hard gate before merge, Spec 16 §C):** start a ride online, pan to load tiles,
  enable airplane mode mid-ride → previously-viewed tiles must still render (not blank); recording
  continues; offline banner shows. **If stale tiles blank out offline** (the exact bug flutter_map had
  before `overrideFreshAge`), the ambient cache is revalidating-and-failing — fall back to an explicit
  offline region via `OfflineManager.downloadRegion(...)` around the active area, or
  `invalidateAmbientCache` tuning. Record the outcome in the spec's Acceptance checklist.

**Gate:** analyze + test (unchanged suite green; device check tracked separately).

---

## Task 8 — Cleanup + final gate

- Delete the throwaway spike `lib/dev/maplibre_demo.dart` (Spec 16 §Acceptance — before merge).
- `grep -rn "flutter_map\|latlong2\|maplibre_demo" lib test` → empty.
- Final `flutter analyze` (clean) + `flutter test` (full suite green).
- Update memory `live-map-maplibre-topo.md`: mark the integration landed, list the remaining standing
  device gates (iOS smoothness/style load, airplane-mode tile rendering).

---

## Standing manual gates (NOT code tasks — tracked to merge)

Per the project's "device-verify on BOTH Android and iOS before merge" rule:
- **iOS (iPhone):** smooth fractional zoom / world-fit / pan; `topo-v2` + `basic-v2-dark` both load;
  route + dots crisp; recenter/follow behave; hand-pan drops follow. (Spike was Android-only.)
- **Android (Pixel 7):** re-confirm in the real LiveMap (spike already ✅): dense route while
  recording, per-fix `updateGeoJsonSource`, follow.
- **Offline (both):** airplane mode mid-ride → previously-viewed tiles render; recording continues;
  banner shows (Task 7 verify).

## Out of scope (Spec 16 §Out of scope)
Heading-up rotation, plugin 0.3.5 upgrade, a custom dark "topo" style, preview pipeline / GPS / Live
Activities — untouched.
