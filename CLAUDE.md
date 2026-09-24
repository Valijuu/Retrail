# Retrail — Flutter Project Guide

Retrail is a GPS route-tracker for longboard / skate rides, migrated from an Android (Jetpack Compose) app to **Flutter (Android + iOS)**. Recreate **all functions and designs exactly as the original app**, with one deliberate improvement: ride-preview thumbnails are pre-rendered once and cached (see `lib/map/CLAUDE.md`).

> The full migration roadmap lives in the plan file referenced during setup. Per-phase specs live in `docs/specs/`. Work one phase at a time; each phase is reviewed before implementation and built **test-first**.

## Keep this file current

Whenever a change replaces or updates something documented here (tech stack choice, dependency, tile layout, architecture decision), update the relevant CLAUDE.md entry as part of that same change — not as a separate follow-up. This file describes the current state of the project, not its history.
---

## Project rules (apply to every change)

- All UI is **Flutter** with **Material 3** (`useMaterial3: true`). Follow Material 3 component and naming conventions.
- **Never inline user-facing strings.** All translatable text comes from ARB localization (`AppLocalizations.of(context)`), English default + German. Add a new key to **both** `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb` — never a literal in a widget. Use ICU plurals for count copy and the greetings list for `skater_greetings`. See `lib/l10n/CLAUDE.md` for the German string reference.
- Use the **design tokens** in `lib/core/theme/CLAUDE.md` for every color, shape, and typography decision. No hardcoded hex outside the token set (`AppColors` ThemeExtension).
- **Widget, Riverpod-provider, and Drift-DAO tests follow Red-Green-Refactor.** Write the test first, watch it fail for the right reason (a compile error, then a runtime/assertion failure), then write the minimal code to make it pass, then refactor. These have clear, deterministic input → output boundaries (rendered widget tree / provider state / query result) even though they need more setup ceremony (`pumpWidget`, `ProviderContainer`, an in-memory DB) than pure functions do.
- **Platform-integration, golden, and E2E tests are the exception — tests accompany the implementation rather than strictly preceding it.** The GPS/location pipeline, `flutter_foreground_task`, notifications/Live Activity, golden/visual tests, and true end-to-end flows depend on non-deterministic platform/timing state, so a clean, single, predictable "red" usually isn't achievable before the code exists. Write these alongside the implementation, not necessarily before it.
- A phase is not done until `flutter analyze` is clean and `flutter test` passes. Tests run automatically via hook at the end of each task.
- **Pure domain logic uses EXACT, exclusively.** For extractable, side-effect-free logic in `lib/domain/` (Haversine/distance calc, `RideStats`, formatters, projection math, filter/dedup logic — anything testable as pure input → output with no widget tree, Riverpod wiring, Drift DB, or network access) always use the global `tdd-dart` skill instead of writing tests ad hoc: `Skill({ skill: "tdd-dart" })` → `/test-list-dart` → `/red-dart` → `/green-dart` → `refactor` subagent (the `refactor` agent is shared, unchanged, with the TypeScript variant — it's language-agnostic). This is Retrail's Dart/Flutter counterpart to the EXACT methodology used in other projects for pure logic (e.g. `anime-news-de`); see `~/.claude/skills/tdd-dart/` for the skill itself. Faustregel: isolable without a real Flutter widget tree/DB/network call → EXACT. Needs a widget tree, provider wiring, a Drift DB, or any other side effect → stays on the Red-Green-Refactor / test-alongside rules above; do **not** use EXACT there (the `skip:`/prediction ceremony isn't built for that shape of test).
- Keep state logic in **Riverpod providers** (the ViewModel layer).
- Match the original app's behavior precisely — distances, speeds, filters, formatting, GPS filtering thresholds, and offline handling are all specified per-phase and backed by ported tests.

---

## Git workflow

One short-lived branch per feature/phase. `main` stays always-green and linear.

1. **Branch:** before implementing a phase, create `phase/NN-<name>` off the latest `main`.
2. **Implement test-first** on that branch. Commit as you go.
3. **Done = green:** a feature is only complete when `flutter analyze` is clean and `flutter test` passes.
4. **Integrate:** rebase the branch onto the latest `main` (linear history), then fast-forward `main` to it.
5. **Clean up:** delete the feature branch after the fast-forward merge.

Never merge or commit red/broken code to `main`.

## Debugging

Invoke the debugging skill (`.claude/skills/root-cause-debugging/SKILL.md`) when the bug spans multiple files, is intermittent, has multiple plausible root causes, or a quick fix already failed. Skip it for trivial, single-file, obviously-located bugs — fix directly with a short explanation. If unsure whether a bug qualifies as complex → default to invoking the skill.

---

## Tech stack

| Concern | Choice |
|---|---|
| UI | Flutter, Material 3 |
| State management | **Riverpod** (`flutter_riverpod`, hand-written providers — no code generation) — replaces Android ViewModel + StateFlow |
| Persistence | **Drift** (SQLite, reactive `Stream`s) — replaces Room |
| Preferences | `shared_preferences` (behind `PreferencesRepository`) — replaces DataStore |
| Maps (live) | **`maplibre`** (native MapLibre GL, vector style) |
| Map previews | Pre-rendered PNG snapshots (`CustomPainter → toImage → PNG`), cached on disk — NO live map per list item |
| Background GPS | **`flutter_foreground_task`** (Android service + notification) + **`geolocator`** (location + iOS background modes) |
| Notifications | Android: the `flutter_foreground_task` service notification (title + Pause/Stop). iOS: **Live Activity** (Swift ActivityKit) planned; `flutter_local_notifications` is a dependency but not yet used — keep or drop decided with the iOS pass (issue #35) |
| Images / crop | `image_picker` + `image_cropper` — replaces camera intent + uCrop |
| Localization | `flutter_localizations` + `intl`, ARB files (`en` default, `de`) |
| Tile source | **MapTiler** `topo-v2` / `basic-v2-dark` (existing API key) — vector style for the live map, `@2x` raster tiles for previews |
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
└── map/                          # MapLibre live map, preview snapshot pipeline, projection math
```

**Conventions**
- One Riverpod provider set per feature (`*_providers.dart`); expose read-only state, accept intents as methods. Mirrors the original ViewModels 1:1 (`HomeViewModel` → `homeProvider`, etc.).
- Repositories return Drift `Stream`s; providers transform them (stats, filtering, grouping) exactly as the Kotlin ViewModels did.
- `RideTracker` is a process-lifetime singleton provider (survives screen disposal), exposing live `location`, `trackPoints`, `distance`, `speed`, `elapsed`, `isPaused`, `activityType`. Recording is fully local and works offline.
- Naming: files `snake_case.dart`, types `UpperCamelCase`, providers `camelCaseProvider`.

---

## Code quality conventions

- **Single responsibility:** one provider/repository/widget = one job. If a file grows past ~300 lines or mixes concerns, split it.
- **Depend on abstractions:** features depend on repository / `*Repository` APIs, never on Drift / SharedPreferences directly. Inject collaborators (DAO, `Clock`) via constructors / providers — no globally-reached singletons.
- **No logic in widgets:** widgets read state + send intents; computation lives in providers or `domain/`.
- **Pure & testable:** domain math (Haversine, stats, projection) is pure Dart with no Flutter imports, fully unit-tested.
- **Small, named things:** intent-named constants over magic numbers (e.g. `AppShapes.card`); no dead code (the original's dead code was intentionally dropped).
- **Immutability:** state classes are immutable (`copyWith`); prefer `const`.

### Interfaces (Dart-idiomatic, not Java-style)
Every Dart class already exposes an implicit interface, and `mocktail` mocks concrete classes — so don't create interfaces just for testing or just to "depend on an abstraction."
- **Introduce an explicit `abstract interface class` only at real seams** — a boundary with a genuine alternate/fake implementation or a platform dependency (e.g. `DistanceCalculator`, `ConnectivityObserver`, location source, notifications).
- **Keep single-implementation repositories concrete** (`RideRepository`, `TrackpointRepository`) — no `…Impl` ceremony; test with `mocktail` or a real in-memory Drift DB.
- **Use a `typedef` function for tiny strategy seams** (e.g. the injected `Clock`/`NowMs`), not a one-method interface.
