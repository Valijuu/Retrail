# Retrail — Flutter Project Guide

Retrail is a GPS route-tracker for longboard / skate rides, migrated from an Android (Jetpack Compose) app to **Flutter (Android + iOS)**. Recreate **all functions and designs exactly as the original app**, with one deliberate improvement: ride-preview thumbnails are pre-rendered once and cached (see *Map & previews*).

> The full migration roadmap lives in the plan file referenced during setup. Per-phase specs live in `docs/specs/`. Work one phase at a time; each phase is reviewed before implementation and built **test-first**.

---

## Global rules (apply to every change)

- All UI is **Flutter** with **Material 3** (`useMaterial3: true`). Follow Material 3 component and naming conventions.
- **Never inline user-facing strings.** All translatable text comes from ARB localization (`AppLocalizations.of(context)`), English default + German. Add a new key to **both** `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb` — never a literal in a widget. Use ICU plurals for count copy and the greetings list for `skater_greetings`.
- Use the **design tokens** below for every color, shape, and typography decision. No hardcoded hex outside the token set (`AppColors` ThemeExtension).
- **Test-first.** Every function/feature gets a test written before (or alongside) the implementation. A phase is not done until `flutter analyze` is clean and `flutter test` is green.
- Keep state logic in **Riverpod providers** (the ViewModel layer). Widgets are thin; they read state and send intents. Don't put business logic in widgets.
- Match the original app's behavior precisely — distances, speeds, filters, formatting, GPS filtering thresholds, and offline handling are all specified per-phase and backed by ported tests.

---

## Git workflow

One short-lived branch per feature/phase. `main` stays always-green and linear.

1. **Branch:** before implementing a feature/phase, create `feature/<name>` (or `phase/NN-<name>`) off the latest `main`.
2. **Implement test-first** on that branch. Commit as you go.
3. **Done = green:** a feature is only complete when `flutter analyze` is clean and `flutter test` passes.
4. **Integrate:** rebase the branch onto the latest `main` (linear history), then fast-forward `main` to it.
5. **Clean up:** delete the feature branch after the fast-forward merge.

Never merge or commit red/broken code to `main`.

## Tech stack

| Concern | Choice |
|---|---|
| UI | Flutter, Material 3 |
| State management | **Riverpod** (`flutter_riverpod` / `riverpod_annotation`) — replaces Android ViewModel + StateFlow |
| Persistence | **Drift** (SQLite, reactive `Stream`s) — replaces Room |
| Preferences | Drift table or `shared_preferences` — replaces DataStore |
| Maps (live) | **`flutter_map`** (pure-Dart) + `flutter_map_tile_caching` (FMTC) |
| Map previews | Pre-rendered PNG snapshots (`CustomPainter → toImage → PNG`), cached on disk — NO live map per list item |
| Background GPS | **`flutter_foreground_task`** (Android service + notification) + **`geolocator`** (location + iOS background modes) |
| Notifications | `flutter_local_notifications` (Android) + **iOS Live Activity** (Swift ActivityKit) for lock-screen controls |
| Images / crop | `image_picker` + `image_cropper` — replaces camera intent + uCrop |
| Localization | `flutter_localizations` + `intl`, ARB files (`en` default, `de`) |
| Tile source | **MapTiler** `streets-v2` / `streets-v2-dark` (existing API key) |
| Testing | `flutter_test`, `mocktail`, `drift` in-memory DB for DAO tests |

---

## Architecture

Feature-first layout, mirroring the original packages. Providers are the ViewModel layer; repositories own data sources; a long-lived `RideTracker` provider owns recording state.

```
lib/
├── main.dart
├── app.dart                      # MaterialApp + theme + localization wiring
├── l10n/                         # app_en.arb, app_de.arb (generated AppLocalizations)
├── core/
│   ├── theme/                    # AppColors (ThemeExtension), typography, shapes, theme builder
│   ├── connectivity/             # ConnectivityObserver (VPN-aware HTTP probe)
│   └── util/                     # formatters, date/week/day/year bounds
├── data/
│   ├── db/                       # Drift database, tables (Ride, Trackpoint), DAOs
│   ├── repositories/             # RideRepository, TrackpointRepository, PreferencesRepository
│   └── models/                   # plain data models / DTOs
├── domain/                       # DistanceCalculator (Haversine), RideStats, pure logic
├── features/
│   ├── onboarding/  home/  timer/  active_ride/  history/  settings/  profile/
│   │     each: <feature>_screen.dart, <feature>_providers.dart, widgets/
│   └── shell/                    # splash, main tabs + bottom nav, routing, deep-link
├── tracking/                     # RideTracker (singleton provider), location pipeline, foreground task
└── map/                          # flutter_map live map, preview snapshot pipeline, projection math
```

**Conventions**
- One Riverpod provider set per feature (`*_providers.dart`); expose read-only state, accept intents as methods. Mirrors the original ViewModels 1:1 (`HomeViewModel` → `homeProvider`, etc.).
- Repositories return Drift `Stream`s; providers transform them (stats, filtering, grouping) exactly as the Kotlin ViewModels did.
- `RideTracker` is a process-lifetime singleton provider (survives screen disposal), exposing live `location`, `trackPoints`, `distance`, `speed`, `elapsed`, `isPaused`, `activityType`. Recording is fully local and works offline.
- Naming: files `snake_case.dart`, types `UpperCamelCase`, providers `camelCaseProvider`.

---

## Map & previews (the key improvement)

- **Live/active-ride map:** `flutter_map`, route drawn as halo (white, wider) + blue line on top; heading-up rotation when moving > 1.5 m/s; smooth follow; activity/start/end markers.
- **Ride previews (history & home):** rendered **once at ride-save** — fetch the basemap tiles for the route's framing (Web Mercator bounds, zoom capped at `MAX_PREVIEW_ZOOM = 16`), paint halo+blue polyline on top, export to a **disk-cached PNG** keyed by `rideId`. Lists show `Image.file(...)` → no tiles, no network, no GL during scroll.
- **Offline at save-time:** store a flat `RouteSketch` PNG (polyline over `MapTerrain`), mark stale, regenerate full-tile snapshot when back online. Evict the cached image on ride edit/delete.
- Port projection math verbatim with its tests: `lonXAtZoom`, `latYAtZoom`, `latYFrac`, `projectPoint`, `computeFraming`, zoom cap, degenerate-bbox handling.

## Offline behavior

GPS recording and ride saving are **fully local — no internet required**. Only map *tiles* need the network. In flight mode: recording continues, the route polyline still draws, an offline banner shows, the ride saves with a flat preview that regenerates later. `ConnectivityObserver` uses an active HTTP `generate_204` probe (NOT the OS "validated" flag, which some VPNs fake), polled every 10s + on network change.

---

## Design tokens

### Colors — light

```dart
// Brand / primary
Primary            = 0xFFB45309   OnPrimary          = 0xFFFFF8F5
PrimaryContainer   = 0xFFFFEDD5   OnPrimaryContainer = 0xFF431407
// Surfaces
Surface            = 0xFFFFF8F5   OnSurface          = 0xFF1C1B1F
SurfaceContainer   = 0xFFF3EDE8   OnSurfaceVariant   = 0xFF857470
SubtleText         = 0xFFA89080   HintText           = 0xFFC8B8A8
// Chips / actions
ChipSecondary      = 0xFFFED7AA   ChipSecondaryText  = 0xFF7C2D12
EditActionBg       = 0xFFFFEDD5   EditActionText     = 0xFF92400E
DeleteActionBg     = 0xFFFEE2E2   DeleteActionText   = 0xFFB91C1C
LiveIndicator      = 0xFFFFBB70
// Map
MapTerrain         = 0xFFDDE8DD   MapTerrainGrid     = 0xFFCCE0CC
RouteLineBlue      = 0xFF2563EB   RouteLineHalo      = 0xFFFFFFFF
MarkerStartGreen   = 0xFF16A34A   MarkerEndRed       = 0xFFDC2626
```

### Colors — dark

```dart
DarkSurface          = 0xFF1C1B1F   DarkSurfaceContainer = 0xFF2B2118
DarkPrimary          = 0xFFF59E42   DarkOnPrimary        = 0xFF431407
DarkPrimaryContainer = 0xFF7C3A0A   DarkOnPrimaryContainer = 0xFFFFEDD5
DarkOnSurface        = 0xFFF3EDE8   DarkOnSurfaceVariant = 0xFFB5A8A0
DarkSubtleText       = 0xFF8A7C70   DarkHintText         = 0xFF6E6258
DarkChipSecondary    = 0xFF7C3A0A   DarkChipSecondaryText= 0xFFFED7AA
DarkEditActionBg     = 0xFF3A2A12   DarkEditActionText   = 0xFFFCD9A6
DarkDeleteActionBg   = 0xFF3A1A1A   DarkDeleteActionText = 0xFFFCA5A5
DarkLiveIndicator    = 0xFFFFBB70
DarkMapTerrain       = 0xFF20292A   DarkMapTerrainGrid   = 0xFF2C3A3A
// Route line colors are identical across themes.
```

Tokens live in an `AppColors` `ThemeExtension`; access via `Theme.of(context).extension<AppColors>()!`. Dynamic color is OFF — Retrail uses brand colors on both themes. Theme mode (system/light/dark) is user-selectable and persisted.

### Shapes

```
RoundedRectangleBorder radius 14  // hero card, route maps
                       radius 12  // recent-ride cards, stat cells
                       radius 50  // FAB / pill buttons
                       radius 10  // GPS status line, dialog inputs
                       radius 8   // small icon containers
```

### Typography (Material 3 mapping)

| Element | M3 style |
|---|---|
| Page title ("Retrail") | `titleLarge` |
| Greeting | `labelSmall`, dimmed |
| Hero number (24.3 km) | `displaySmall` |
| Hero unit | `titleSmall`, dimmed |
| Section labels ("Recent rides") | `labelSmall`, uppercase, dimmed |
| Card title | `bodyMedium`, medium weight |
| Card metadata | `labelSmall`, dimmed |
| Primary button | `labelLarge` |
| Stat value | `titleMedium` |
| Stat label | `labelSmall`, dimmed |

---

## German string reference (translation source for `app_de.arb`)

English is the default and should read naturally (not a literal back-translation). German wording reference:

| Key | German |
|---|---|
| App title | Retrail |
| Greeting | Guten Morgen |
| This week | Diese Woche |
| Rides count suffix | über X Fahrten |
| Avg speed chip | Ø X km/h |
| Recent rides | Letzte Fahrten |
| Start tracking | Tracking starten |
| Nav: Home / History / Settings | Start / Verlauf / Einstellungen |
| Countdown label | Fertig machen |
| Countdown tagline | Fahrt beginnt gleich. / Bleib in Balance. |
| GPS status / locked | GPS-Signal / bereit |
| Start now | Jetzt starten |
| Skip countdown | Countdown überspringen |
| Active ride title | Longboard-Fahrt |
| Live badge | Live |
| Stats | Tempo / Strecke / Dauer / Höchstgeschw. |
| Stop ride | Fahrt beenden |
| End dialog title / subtitle | Wie war die Fahrt? / Füge eine Notiz hinzu. |
| Title / Comment inputs | Titel / Kommentar |
| Skip / Save | Überspringen / Speichern |
| History title | Fahrtenverlauf |
| Filter chip | Diese Woche |
| Today / Yesterday | Heute / Gestern |
| Great pace / No route | Gutes Tempo / Keine Route |
| Swipe hint | ← wischen zum Bearbeiten oder Löschen |
| Edit / Delete | Bearbeiten / Löschen |
