# Spec 2 — Design System (typography, shapes, component themes)

**Status:** awaiting review
**Phase:** 2 of 15
**Depends on:** Spec 1 (AppColors ThemeExtension already exists)

## Goal
Complete the visual foundation so every later screen pulls type, shape, and component styling from one source — matching the original app exactly. Spec 1 added the color tokens and a minimal `buildTheme`; this phase fills in **typography**, **shapes**, and the **Material 3 component themes**, all driven by the tokens.

## Background (from the original app)
- The original `Type.kt` only overrode `bodyLarge` and otherwise used Material 3 defaults — so typography is **M3 defaults plus the role mapping** in `CLAUDE.md`, not a custom font. No custom font files shipped.
- Shapes used across the app: radius **14** (hero card, route maps), **12** (recent-ride cards, stat cells), **50** (FAB / pill buttons), **10** (GPS status line, dialog inputs), **8** (small icon containers).
- Colors are already tokenized (`AppColors`, light + dark) from Spec 1.

## Deliverables

### 1. `core/theme/app_shapes.dart`
A small holder of the five `BorderRadius`/`RoundedRectangleBorder` constants (r14, r12, r50, r10, r8) with intent-named accessors (`AppShapes.heroCard`, `AppShapes.card`, `AppShapes.pill`, `AppShapes.input`, `AppShapes.iconContainer`). No magic numbers in feature code.

### 2. `core/theme/app_typography.dart`
- Build the Material 3 `TextTheme` (M3 defaults; override only what the original did, e.g. `bodyLarge`).
- Provide a documented mapping table in code comments tying each role to its usage (page title → `titleLarge`, hero number → `displaySmall`, etc., per `CLAUDE.md`).
- Optionally expose semantic helpers (e.g. `context.appText.heroNumber`) only if it reduces repetition — otherwise screens use `Theme.of(context).textTheme.*` directly. Keep it minimal (YAGNI).

### 3. Extend `buildTheme(Brightness)` (Spec 1 file)
Wire the tokens into M3 component themes so widgets inherit correct styling without per-widget overrides:
- `textTheme` ← `app_typography`.
- `cardTheme` ← surfaceContainer bg, `AppShapes.card`.
- `filledButton`/`elevatedButton`/`textButton` themes ← primary/onPrimary, `AppShapes.pill`, `labelLarge`.
- `floatingActionButtonTheme` ← primary, `AppShapes.pill`.
- `inputDecorationTheme` ← `AppShapes.input`, hintText token.
- `chipTheme` ← chipSecondary/chipSecondaryText.
- `appBarTheme`, `bottomNavigationBar`/`navigationBarTheme` ← surface, primary selection.
- `dividerTheme`, `snackBarTheme` as needed.
All colors come from `AppColors`/`colorScheme`; no literals.

### 4. (Optional) `BuildContext` extension
`context.colors` → `Theme.of(context).extension<AppColors>()!` for terse, safe access in feature code. Single tiny file in `core/theme/`.

## Test-first plan
1. `test/theme/app_shapes_test.dart` — each shape constant has the expected radius (14/12/50/10/8).
2. `test/theme/typography_test.dart` — `buildTheme` produces a non-null `textTheme` with the expected roles populated; any overridden role (e.g. `bodyLarge`) matches the original's value.
3. `test/theme/component_theme_test.dart` — pump a `MaterialApp(theme: buildTheme(light))` with a `FilledButton`, `Card`, `TextField`, `Chip`; assert resolved shape radius + key colors come from tokens (e.g. button shape radius 50, card color == surfaceContainer). Widget-level, deterministic.
4. **One golden test** (`test/theme/golden/`) — a small "design system sampler" widget (button, card, chip, stat cell, input) rendered in light + dark, to lock the visual baseline. Golden files committed; documented `flutter test --update-goldens` workflow for intentional changes.
5. `context.colors` extension returns the same instance as `Theme.of(context).extension<AppColors>()`.

Write tests first (red) → implement → green.

## Acceptance criteria
- `flutter analyze` clean; `flutter test` green (incl. goldens).
- No hardcoded hex or raw radii anywhere outside `core/theme/`.
- A throwaway sampler screen visually matches the original's look in light + dark (manual check).
- Branch `phase/02-design-system` rebased + fast-forwarded onto `main`, then deleted.

## Out of scope
Per-screen layouts (their phases), navigation, any data. This phase only produces the reusable styling layer.
