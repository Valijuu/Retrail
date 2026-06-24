# Spec 8 — Navigation & App Shell

**Status:** DONE — merged to `main`; 12 new shell tests (151 total) green, analyze clean.
**Phase:** 8 of 15

> **Note (Riverpod 3):** `StateProvider` lives in `package:flutter_riverpod/legacy.dart`; `AsyncValue` uses `.asData?.value` (not `valueOrNull`).
**Depends on:** Spec 1 (l10n, app entry), Spec 2 (theme), Spec 3 (`PreferencesRepository`)

## Goal
Stand up the app skeleton: routing with fade transitions, the splash → onboarding gate, the 3-tab bottom-nav shell, theme-mode wiring, and the active-ride deep-link hook. Screen bodies are **placeholders** here; later phases (9 onboarding, 10 home, 11 timer, 12 active-ride, 13 history, 14 settings) fill them in. This unblocks every screen phase.

## Routing approach
Use **`go_router`** (add dependency). It maps cleanly to the original: named routes, a `redirect` for the onboarding gate, and built-in deep-linking for the ongoing-ride notification. Fade transitions (180ms) via `CustomTransitionPage`, matching the original's symmetric fades.

### Routes (mirror `NavigationItem`)
`lib/features/shell/routes.dart` — names + paths:
- `splash` `/splash`
- `init` `/init`, `profilePicture` `/init/photo`, `activityPicker` `/init/activity`
- `main` `/` (the tab shell — was `StartPage`/`MainTabsPage`)
- `timer` `/timer`
- `ride` `/ride` (active-ride map — was `MapPage`)

## Deliverables

### 1. `startup_provider.dart`
Exposes onboarding state from `PreferencesRepository.onboardingDone` (Spec 3) as a Riverpod provider: `AsyncValue<bool>` / a `bool?` (null while loading). Mirrors the original `StartupViewModel`.

### 2. `app_router.dart` (go_router)
- `redirect`: while onboarding state is unknown → `splash`; once known → `init` if not done, else stay/`main`. A `refreshListenable` bridges the Riverpod provider so the redirect re-runs when it resolves.
- Fade `pageBuilder` for all routes (180ms in/out).
- **Active-ride deep link:** a `pendingRideDeepLink` provider (a flag/notifier); the router redirects to `/ride` when set, then clears it. The Android notification (Spec 5 Part B) and iOS (Spec 6) set this flag. Mirrors the original `openRideSignal` + `launchSingleTop`.

### 3. `theme_mode_provider.dart`
Maps `PreferencesRepository.themeMode` (`"system"`/`"light"`/`"dark"`) → `ThemeMode`. `app.dart` watches it for `MaterialApp.router(themeMode: …)`. (Original `ThemeViewModel` + `MainActivity` resolution; Flutter resolves "system" itself.)

### 4. `main_shell.dart` — the 3-tab shell
- `PageView` (swipeable) + Material 3 `NavigationBar` bottom bar; **one tab list is the single source of truth** for both (label l10n key + icon), as in the original.
- Tabs: **Home / History / Settings** (`nav_home`/`nav_history`/`nav_settings`).
- Selected styling matches the original: selected icon sits in a `primaryContainer` pill (radius 50), `primary` icon+label; unselected `subtleText`; transparent indicator; 0.5dp top divider at `onSurfaceVariant @20%`.
- Tab tap → `PageController.animateToPage`; swipe syncs selection.
- **`homeVisits` counter:** increments each time the Home tab becomes current — passed to Home so the random greeting re-rolls per visit (original behavior).
- **`targetRideId` hand-off:** tapping a ride on Home switches to the History tab and scrolls to that ride. Modeled as a small shared provider (`historyTargetRideProvider`) the History screen consumes and clears.

### 5. Screen placeholders
`splash` (blank/centered logo), `init`/`photo`/`activity`, `timer`, `ride`, and the three tab bodies render simple placeholders (e.g. centered route name) so the shell builds and is testable. Each later phase replaces its placeholder.

### 6. App wiring (`main.dart` / `app.dart`)
- `main()`: `WidgetsFlutterBinding.ensureInitialized()`, `await SharedPreferences.getInstance()`, `await initializeDateFormatting()`, then `runApp(ProviderScope(overrides: [preferencesRepositoryProvider.overrideWithValue(PreferencesRepository(prefs))], child: RetrailApp()))`.
- `app.dart`: `MaterialApp.router(routerConfig: …, theme/darkTheme: buildTheme(...), themeMode: <provider>, localizationsDelegates, supportedLocales)`. Replaces the Spec 1 placeholder home.

### 7. Localization
Add `nav_home`/`nav_history`/`nav_settings` to `app_en.arb` + `app_de.arb` (EN: Home/History/Settings; DE: Start/Verlauf/Einstellungen).

## Test-first plan (`test/shell/`)
1. `startup_redirect_test.dart` — with onboardingDone=false the router resolves to `init`; =true → `main`; while loading → `splash`. (Override `preferencesRepositoryProvider` with an in-memory prefs.)
2. `theme_mode_test.dart` — `"dark"`→`ThemeMode.dark`, `"light"`→`ThemeMode.light`, `"system"`/unknown→`ThemeMode.system`.
3. `main_shell_test.dart` — renders 3 nav destinations; tapping History shows the History placeholder; selection styling reflects the current tab; returning to Home increments the greeting key.
4. `deep_link_test.dart` — setting `pendingRideDeepLink` routes to `/ride` and clears the flag.

Existing `test/foundation/app_boots_test.dart` updates to the new shell (still asserts the app boots).

## Acceptance
- `flutter analyze` clean; `flutter test` green.
- App launches to the tab shell (or init on first run); tabs swipe + tap; theme follows the pref.
- Branch `phase/08-navigation-shell` rebased + fast-forwarded onto `main`, then deleted.

## Out of scope
Real screen content (their phases), GPS deep-link *triggering* (Spec 5 Part B sets the flag this phase reads), profile editing.
