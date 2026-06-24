# Spec 1 — Project Bootstrap & Foundation

**Status:** DONE — merged to `main` (commit `e27736d`); 7 smoke tests green, analyze clean
**Phase:** 1 of 15
**Depends on:** none

## Goal
Stand up the `retrail` Flutter project skeleton so every later phase has its dependencies, folder structure, localization, theming hook, and test harness ready. No feature logic yet — this phase is plumbing only, but it must compile, analyze clean, and pass a trivial test.

## Already done (this session)
- `flutter create --org com.retrail --project-name retrail --platforms android,ios retrail`
- `git init`, `docs/specs/` created
- `CLAUDE.md` written (project guide + design tokens)

## Deliverables

### 1. Dependencies (`pubspec.yaml`)
Runtime:
- `flutter_riverpod`, `riverpod_annotation`
- `drift`, `sqlite3_flutter_libs`, `path_provider`, `path`
- `flutter_map`, `latlong2`, `flutter_map_tile_caching`
- `geolocator`, `flutter_foreground_task`, `flutter_local_notifications`
- `image_picker`, `image_cropper`
- `flutter_localizations` (sdk), `intl`
- `http` (connectivity probe + tile fetch), `connectivity_plus`

Dev:
- `flutter_test` (sdk), `flutter_lints`
- `build_runner`, `riverpod_generator`, `drift_dev`
- `mocktail`
- `integration_test` (sdk)

Exact versions resolved via `flutter pub add`; lockfile committed. (We deliberately do NOT add: osmdroid/maplibre, coil/truth equivalents — see roadmap "Do NOT port".)

### 2. Folder structure
Create the empty package tree from `CLAUDE.md` › Architecture (`core/`, `data/`, `domain/`, `features/`, `tracking/`, `map/`, `l10n/`) with `.gitkeep` placeholders where needed.

### 3. Localization scaffold
- `l10n.yaml` (arb-dir `lib/l10n`, template `app_en.arb`, output `AppLocalizations`).
- `app_en.arb` + `app_de.arb` seeded with just `appTitle` ("Retrail") to prove generation.
- Wire `AppLocalizations.delegate` + `supportedLocales` into `app.dart`; locale resolves system → en/de (full switch UI comes in Settings phase).

### 4. Theme hook
- Minimal `core/theme/`: `AppColors` `ThemeExtension` with the token fields from `CLAUDE.md` (light + dark instances) and a `buildTheme(Brightness)` returning a Material 3 `ThemeData` with the extension attached. Full typography/shape wiring is Spec 2 — here we only need it to compile and be reachable.

### 5. App entry
- `main.dart` → `ProviderScope(child: RetrailApp())`.
- `app.dart` → `MaterialApp` with `theme`/`darkTheme`/`themeMode: system`, localization delegates, and a placeholder home `Scaffold` showing `appTitle` (replaced by the shell in Spec 8).

### 6. Analysis & CI hygiene
- `analysis_options.yaml`: `flutter_lints` + `prefer_const`, treat-warnings strictly; exclude generated `*.g.dart` / `*.freezed.dart` / `*.drift.dart`.
- `.gitignore` already covers build artifacts (from `flutter create`); add `/coverage/`.

## Test-first plan
This phase has no business logic, so tests are smoke-level (they still gate the build):
1. `test/foundation/app_boots_test.dart` — pump `RetrailApp` in `ProviderScope`, expect the `appTitle` text renders (proves Riverpod + MaterialApp + localization wiring).
2. `test/foundation/theme_test.dart` — `buildTheme(Brightness.light/dark)` returns `ThemeData` whose `AppColors` extension exposes the expected `primary` token per brightness (proves the ThemeExtension is attached and brightness-correct).
3. `test/foundation/localization_test.dart` — `AppLocalizations` resolves `appTitle` to "Retrail" for `en` and `de`.

Write each test first (red), then implement until green.

## Acceptance criteria
- `flutter pub get` succeeds; `dart run build_runner build` succeeds (no generated code yet beyond l10n, but the toolchain runs).
- `flutter analyze` → no issues.
- `flutter test` → 3/3 pass.
- App launches on an Android emulator showing "Retrail" (manual smoke, optional this phase).
- Initial commit on `main`.

## Out of scope (later phases)
Full color/typography/shape system (Spec 2), Drift schema (Spec 3), any feature screens, GPS, maps.
