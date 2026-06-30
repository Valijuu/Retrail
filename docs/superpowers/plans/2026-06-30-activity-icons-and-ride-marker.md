# Implementation Plan — Custom activity icons + activity-dependent ride marker

**Goal:** Port the Android app's exact activity illustrations and the activity-dependent
ride-screen marker to Retrail (Flutter).
**Roadmap:** belongs to the Polish phase (Spec 15); also completes the deferred note in
`lib/features/onboarding/activity_type_ui.dart` ("Exact custom icons can be recreated as SVGs in the
polish phase.").
**Date:** 2026-06-30
**Decisions (user-approved):** render icons with **flutter_svg** from 7 exact SVG assets; keep the
existing `CircleStyleLayer` blue dot for the `OTHER`/null marker case (visually equivalent to Android's
`makeDotBitmap`).

## Reference — original Android behavior (source of truth)
- `enums/ActivityType.kt`: 7 types, each with a `@DrawableRes ic_activity_*`. `rollerblades` and
  `rollerskates` share the **same** glyph; `skateboard`/`scooter`/`other` are stock Material Symbols;
  `longboard`/`mountainboard` are custom-drawn in the Material style. (All 7 exact paths already shipped
  as `assets/icons/activity/*.svg`, viewBox `0 -960 960 960`.)
- `pages/mapepage/MovingMarkerMap.kt`:
  - `pinImage = when(activityType){ null, OTHER -> makeDotBitmap(72); else -> makeIconBitmap(ctx, iconRes) }`
  - `makeDotBitmap`: white circle radius r + `#2563EB` inner circle radius `0.65r`.
  - `makeIconBitmap`: **96px** image, `#B45309` (amber) filled circle, the activity drawable tinted
    **white**, drawn with **18px padding** (so the glyph fills the centre 60×60).
  - Marker shown via `SymbolLayer(iconImage = image(pinImage), iconSize = 0.5, iconAllowOverlap = true,
    iconIgnorePlacement = true)` on the current-position GeoJSON source.

## Verified Flutter facts
- `lib/domain/activity_type.dart`: enum `ActivityType { longboard, skateboard, rollerblades,
  rollerskates, mountainboard, scooter, other }` with `id`/`fromId`/`defaultType`.
- `lib/features/onboarding/activity_type_ui.dart`: `extension ActivityTypeUi` exposes `IconData get icon`
  (Material stand-ins) + `label(l10n)`.
- **8 icon call sites:** `onboarding/activity_tile.dart:46`, `history/filter_sheet.dart:106`,
  `history/edit_ride_dialog.dart:94`, `history/history_ride_card.dart:185` (passes `IconData` into a
  custom chip — needs a small change), `history/ride_detail_dialog.dart:117`,
  `settings/settings_screen.dart:165`, `timer/countdown_screen.dart:165`,
  `active_ride/active_ride_screen.dart:283`.
- `RideTrackingState.activityType` (`ActivityType?`) exists; `active_ride_screen.dart:269` already reads
  `state.activityType ?? ActivityType.defaultType`.
- maplibre 0.2.2 supports `StyleController.addImage(id, Uint8List)` + `SymbolStyleLayer({id, sourceId,
  layout, paint})` (raw layout/paint maps) — confirmed.
- `LiveMap` currently draws the current dot as a `CircleStyleLayer` (`current-dot`) on the `current`
  GeoJSON source.

## Global rules
Test-first where a pure unit exists. Gate after each task: `flutter analyze` clean AND `flutter test`
green. Tests run without a MapTiler key — fine. Never print/commit the key. Do NOT run `dart format`
repo-wide — only touch named files. Do NOT commit. The native map (and thus the marker raster) does not
render under `flutter test`, so marker visuals are a device gate, not a unit assertion.

---

## Task 1 — flutter_svg dependency + asset registration ✅ DONE (by lead)

- `flutter_svg ^2.3.0` added to `pubspec.yaml` (pulls `vector_graphics`); asset dir
  `assets/icons/activity/` registered under `flutter:`; the 7 SVGs exist. `flutter pub get` run.
- Subagents start from here; nothing to do for Task 1 except confirm `flutter analyze`/`flutter test`
  are green at the start.

---

## Task 2 — Custom icons everywhere (replace Material stand-ins)

**Files:** `lib/features/onboarding/activity_type_ui.dart`, `test/.../activity_type_ui_test.dart` (new),
and the 8 call sites above.

**RED** — new pure test for the asset mapping (`test/onboarding/activity_type_ui_test.dart` or beside
the existing activity test):
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/activity_type.dart';
import 'package:retrail/features/onboarding/activity_type_ui.dart';

void main() {
  test('every activity type maps to its bundled SVG asset', () {
    for (final t in ActivityType.values) {
      expect(t.iconAsset, 'assets/icons/activity/${t.name}.svg');
    }
  });
}
```
> `ActivityType.name` yields `longboard`, `skateboard`, … which matches the asset filenames exactly —
> so `iconAsset` is `'assets/icons/activity/${name}.svg'`. Confirm `name` casing during impl; if it
> differs, use an explicit `switch` instead (do not rename assets).

**GREEN** — in `activity_type_ui.dart`:
- Add `String get iconAsset => 'assets/icons/activity/$name.svg';`
- Replace the `IconData get icon` getter with a widget builder (remove the Material `icon` getter):
  ```dart
  /// The activity's custom glyph, tinted [color] (defaults to the ambient icon
  /// colour). Single-colour SVG, so a srcIn tint recolours the whole glyph.
  Widget glyph({double size = 24, Color? color}) => SvgPicture.asset(
        iconAsset,
        width: size,
        height: size,
        colorFilter:
            color == null ? null : ColorFilter.mode(color, BlendMode.srcIn),
      );
  ```
  (import `package:flutter/widgets.dart` + `package:flutter_svg/flutter_svg.dart`.)
- Keep `label(l10n)` unchanged.

**Update the 8 call sites** — replace `Icon(x.icon, size: S, color: C)` with `x.glyph(size: S, color: C)`:
- `activity_tile.dart:46` → `type.glyph(color: tint)` (was no explicit size → keep default 24).
- `filter_sheet.dart:106` (`avatar: Icon(type.icon, size: 18)`) → `avatar: type.glyph(size: 18)`.
- `edit_ride_dialog.dart:94` (`avatar: Icon(option.icon, size: 18)`) → `avatar: option.glyph(size: 18)`.
- `ride_detail_dialog.dart:117` → `activity.glyph(size: 18, color: colors.primary)`.
- `settings_screen.dart:165` → `activity.glyph(size: 24, color: colors.primary)`.
- `countdown_screen.dart:165` → `activity.glyph(size: 18, color: _accent.primaryContainer)`.
- `active_ride_screen.dart:283` → `activity.glyph(size: 20, color: _chromeAccent.hintText)`.
- `history_ride_card.dart:185` passes `icon: activity.icon` into a private chip widget that holds an
  `IconData? icon` (ctor at ~:350) and renders it with `Icon(...)`. **Inspect that widget**; convert its
  `IconData? icon` field to a `Widget? icon` (or add a `String? iconAsset`) and have the call site pass
  `activity.glyph(size: …, color: …)` matching the chip's current icon size/colour. Keep the chip's
  other (non-activity) icon usages working — if the chip is reused with Material `IconData` elsewhere,
  prefer adding a `Widget? leading` slot over breaking existing `IconData` callers. Match the existing
  rendered size/colour exactly.

> Some screen tests may assert `find.byIcon(Icons.skateboarding)` etc. Those assertions must change to
> `find.byType(SvgPicture)` (scoped to the widget under test) or to the activity label text. Update any
> that break; do not weaken unrelated assertions.

**Gate:** analyze clean; `flutter test` green.

---

## Task 3 — Activity-dependent ride marker

**Files:** `lib/map/live_map.dart`, `lib/features/active_ride/active_ride_screen.dart`,
`lib/features/history/ride_detail_dialog.dart` (+ fullscreen embed if separate),
`test/map/live_map_marker_test.dart` (new).

**RED** — pure marker decision unit:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/activity_type.dart';
import 'package:retrail/map/live_map.dart';

void main() {
  group('rideMarkerIsBadge', () {
    test('null and OTHER use the plain dot', () {
      expect(rideMarkerIsBadge(null), isFalse);
      expect(rideMarkerIsBadge(ActivityType.other), isFalse);
    });
    test('every other activity uses the icon badge', () {
      for (final t in ActivityType.values.where((t) => t != ActivityType.other)) {
        expect(rideMarkerIsBadge(t), isTrue);
      }
    });
  });
}
```

**GREEN:**
1. Pure decision in `live_map.dart`:
   ```dart
   /// Whether the current-position marker is the activity icon badge (true) or
   /// the plain blue dot (false). Mirrors Android MovingMarkerMap: null/OTHER → dot.
   bool rideMarkerIsBadge(ActivityType? type) =>
       type != null && type != ActivityType.other;
   ```
   (import `../domain/activity_type.dart`.)
2. Add `final ActivityType? activityType;` to `LiveMap` (optional ctor param, default null). Public API
   stays backward-compatible.
3. **Badge raster helper** (in `live_map.dart`), mirroring `makeIconBitmap` (96px, amber, white glyph,
   18px padding). **Transform is PROVEN by probe (see below) — do NOT add `translate(0, 960)`:**
   ```dart
   Future<Uint8List> _activityBadgePng(ActivityType type) async {
     const size = 96.0, pad = 18.0, inner = size - 2 * pad; // 60
     final recorder = ui.PictureRecorder();
     final canvas = Canvas(recorder);
     canvas.drawCircle(const Offset(size / 2, size / 2), size / 2,
         Paint()..color = const Color(0xFFB45309)); // amber badge
     // vector_graphics bakes the viewBox origin into the picture (0..960 space),
     // so just scale the 960-unit glyph into the padded box — NO translate(0,960).
     final info = await vg.loadPicture(SvgAssetLoader(type.iconAsset), null);
     canvas.saveLayer(
         const Rect.fromLTWH(0, 0, size, size),
         Paint()..colorFilter =
             const ColorFilter.mode(Color(0xFFFFFFFF), BlendMode.srcIn)); // tint white
     canvas.save();
     canvas.translate(pad, pad);
     canvas.scale(inner / 960);
     canvas.drawPicture(info.picture);
     canvas.restore();
     canvas.restore();
     info.picture.dispose();
     final img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
     final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
     img.dispose();
     return bytes!.buffer.asUint8List();
   }
   ```
   Imports: `dart:typed_data`, `dart:ui as ui`, `package:flutter_svg/flutter_svg.dart` (exports `vg`,
   `PictureInfo`, `SvgAssetLoader`, `SvgStringLoader`). Signature is
   `vg.loadPicture(BytesLoader loader, BuildContext? context)`.

   **PROVEN by probe (runs in `flutter test`, no device):** rendering a full-viewBox glyph
   (`<svg viewBox="0 -960 960 960"><path d="M0,-960 H960 V0 H0 Z"/></svg>`) through this helper, the
   96px badge centre pixel is white `(255,255,255)` WITHOUT `translate(0,960)`, and amber `(180,83,9)`
   (glyph off-canvas) WITH it. Encode this as a **real test** in this task
   (`test/map/activity_badge_test.dart`), using `SvgStringLoader` so no asset bundle is needed:
   ```dart
   // Render the full-viewBox square via the same transform; assert centre white, corner amber.
   // (Factor the helper to accept a BytesLoader, or expose a @visibleForTesting variant, so the
   //  test drives the exact transform. Centre(48,48)==white(255), corner(2,2)==amber(180,83,9).)
   ```
   This converts the hardest-to-eyeball part into CI instead of a device gate.
4. **Marker MODE is gated by `fitBounds`, matching the two original composables (FIDELITY FIX).** The
   Android live map (`MovingMarkerMap`) draws **route + ONE current marker, no start/end dots**; the
   static/detail map (`StaticRouteMap`) draws **green start + red end dots, no current marker**. Today's
   `LiveMap` wrongly draws all three in both modes. In `_onStyleLoaded`, split by `widget.fitBounds`:
   - **`fitBounds == false` (live / active-ride):** add ONLY the current-position marker on the
     `current` source; do **not** add `start-dot` / `end-dot`.
     - badge (`rideMarkerIsBadge(activityType)` true):
       `await style.addImage('marker-${type.name}', await _activityBadgePng(type));` then
       `SymbolStyleLayer(id: 'current-dot', sourceId: 'current', layout: {'icon-image': 'marker-${type.name}',
       'icon-size': 0.5, 'icon-allow-overlap': true, 'icon-ignore-placement': true})`.
     - dot (null / OTHER): keep the existing blue `CircleStyleLayer` (id `current-dot`).
   - **`fitBounds == true` (detail / fullscreen):** add `start-dot` (green) + `end-dot` (red) as today;
     do **not** add the current marker. (`current` is null here anyway.)

   This **supersedes the earlier "live end-dot tracks `points.last`" change** — the live view has no end
   dot at all, so the end-source live-update in `didUpdateWidget` becomes dead for live mode. Keep
   `didUpdateWidget` updating the `route` source (both modes) and the `current` source (live mode);
   the static `start`/`end` sources are set once at load and never change (points are fixed in detail
   view). Remove the now-unreachable live `end`-source update to avoid confusion.
5. **Pass `activityType` from embedders:**
   - `active_ride_screen.dart` `_ActiveRideMap` builds `LiveMap(...)` — add `activityType: state.activityType`.
   - `ride_detail_dialog.dart` (and any fullscreen map) — `activityType: ActivityType.fromId(ride.typ)`
     (reuse the `activity` value the dialog already resolves for its header icon). These are `fitBounds:
     true`, so they render start/end (no marker) regardless — passing the type is harmless/future-proof.

**Gate:** analyze clean; `flutter test` green (incl. the new badge-transform test). Screen tests stub the
native map via `LiveMap.debugMapBuilderOverride`, so the symbol layer / rasterization never run in
widget tests — no screen-test breakage expected. Confirm the suite stays green.

---

## Task 4 — Final gate + memory

- Final `flutter analyze` (clean) + `flutter test` (green).
- `grep -rn "Icons.skateboarding\|Icons.roller_skating\|Icons.downhill_skiing\|Icons.electric_scooter" lib`
  → should be empty for activity usage (the Material stand-ins are gone).
- Update memory `retrail-rebrand-and-activity-types.md`: note the custom SVG icon set lives in
  `assets/icons/activity/` and the ride marker is amber-badge-with-white-glyph for known types / blue
  dot for OTHER (device-verify the badge rasterization).

## Device gates (manual, before merge)
- Activity icons render correctly (exact glyphs) in onboarding, history cards, filter, settings,
  countdown, active-ride header, detail dialog — light & dark.
- Active-ride marker shows the **amber badge + white activity glyph** for known types and the **blue
  dot** for OTHER; the badge glyph is centred/un-clipped (verify the viewBox translate).

## Out of scope
Hi-dpi badge crispness (Android used a fixed 96px raster; mirror that — larger render is a follow-up).
Heading-up rotation, the rest of the live-map spec (Spec 16) — unchanged.
