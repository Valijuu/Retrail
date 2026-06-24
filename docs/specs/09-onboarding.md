# Spec 9 — Onboarding (name → photo → activity)

**Status:** awaiting review
**Phase:** 9 of 15
**Depends on:** Spec 3 (`PreferencesRepository`), Spec 4 (`ActivityType`), Spec 8 (routes/shell)

## Goal
Build the three onboarding screens and their state, replacing the Spec 8 placeholders. Completing the flow writes prefs and sets `onboardingDone`, so the router lands on the main shell next launch.

## Flow (mirrors the original)
`init` (name) → `profilePicture` (avatar/photo, optional) → `activityPicker` (default activity, **finishes onboarding**) → main.
- `init`: "Let's go" **and** "Skip" both advance (name saved only if non-blank, trimmed).
- `profilePicture`: "Continue"/"Skip" both advance; does **not** finish onboarding.
- `activityPicker`: "Continue" saves the chosen activity as `lastActivityType` **and** sets `onboardingDone`.

## Deliverables

### 1. Onboarding state — `lib/features/onboarding/onboarding_providers.dart`
Ports `InitViewModel` + the profile bits of `ProfileViewModel`:
- `nameInputProvider` (Notifier<String>): `onChange(name)` ignores input > 30 chars.
- `saveName()` — trims; saves via `PreferencesRepository.saveUserName` only if non-empty.
- `finishOnboardingWithActivity(ActivityType)` — `saveLastActivityType(type.id)` + `setOnboardingDone()`.
- Avatar/photo: `avatarIndexProvider`/`customPhotoPathProvider` (from prefs streams), `selectAvatar(index)` (+ clears custom photo), `setCustomPhoto(path)`, `clearCustomPhoto()`.

### 2. Profile photo picking — `lib/features/onboarding/profile_photo_picker.dart`
`abstract interface class ProfilePhotoPicker { Future<String?> pickAndCrop(); }` (returns the saved file path, or null if cancelled). Real impl uses `image_picker` (pick) + `image_cropper` (1:1, 512², q85) + saves to app files (the `ProfileImageHelper` equivalent). **Interface seam** so the screens are testable with a fake; real picker verified on-device.

### 3. Screens — `lib/features/onboarding/`
- `init_screen.dart` — illustration, title + subtitle, name `TextField` (singleLine, words-capitalization, max 30), live `N/30` counter, primary "Let's go" + "Skip"; both call saveName then go to `profilePicture`. Input/buttons styled per tokens (radius 12 input, radius 50 pill).
- `profile_picture_screen.dart` — named/anon greeting, 140dp circular preview (custom photo or preset avatar, primary ring), a horizontal row = upload slot (`AddAPhoto`) + preset avatar(s); tapping upload runs `ProfilePhotoPicker`; tapping an avatar selects it + clears custom photo. Continue/Skip → `activityPicker`.
- `activity_init_screen.dart` — title + hint, **2-column grid of all 7 `ActivityType` tiles** (Longboard preselected), Continue → `finishOnboardingWithActivity` → main (clears the onboarding stack).
- `activity_tile.dart` — reusable selectable tile (icon + label, selected = primary border/container). Reused by Settings + the home start-tracking picker later.

### 4. Router wiring
Replace the `init`/`profilePicture`/`activityPicker` placeholders with the real screens; keep the fade transitions and stack-clearing on completion.

### 5. Localization
Add to `app_en.arb`/`app_de.arb`: `initWelcomeTitle`, `initNameQuestion`, `initNameLabel`, `initNamePlaceholder`, `actionLetsGo`, `actionSkip`, `actionContinue`, `profilePictureGreetingNamed` (`{name}`), `profilePictureGreetingAnon`, `profilePictureSubtitle`, `profilePictureUploadCd`, `activityPickerTitle`, `initActivityHint`, the 7 `activity*` labels, and a11y/crop strings. German per the reference table.

### Icons & illustration — DECISION NEEDED
The original uses **custom Android vector drawables** (`ic_activity_*`, `avatar_route`) that don't convert 1:1 to Flutter. Proposed interim: map each `ActivityType` to the closest **Material icon** (e.g. longboard→`skateboarding`, scooter→`electric_scooter`, …) and use a Material illustration for the init screen. Exact custom icons can be recreated as SVG assets in the polish phase (Spec 15) — I can do that with the vector-design skill if you want pixel parity. **Confirm: Material-icon stand-ins now, or port/recreate the exact icons in this phase?**

## Test-first plan (`test/onboarding/`)
1. `onboarding_state_test.dart` — `onChange` caps at 30 chars; `saveName` trims + skips empty (mock prefs, verify `saveUserName`); `finishOnboardingWithActivity` calls `saveLastActivityType('LONGBOARD')` + `setOnboardingDone`; `selectAvatar` clears custom photo.
2. `init_screen_test.dart` — typing updates the `N/30` counter; >30 chars rejected; tapping "Let's go" saves the name and routes to `profilePicture`.
3. `profile_picture_test.dart` — fake `ProfilePhotoPicker` returns a path → preview switches to the photo; tapping a preset avatar clears the custom photo; Continue routes to `activityPicker`.
4. `activity_init_test.dart` — Longboard preselected; selecting another tile updates selection; Continue sets prefs + `onboardingDone` and lands on main (router integration with in-memory prefs).

## Acceptance
- `flutter analyze` clean; full `flutter test` green.
- Fresh launch walks name → photo → activity → main; relaunch goes straight to main.
- Branch `phase/09-onboarding` rebased + fast-forwarded onto `main`, then deleted.

## Out of scope
Profile editing post-onboarding (Settings, Spec 14), the home start-tracking picker (Spec 10 — reuses `ActivityTile`), real camera/crop device verification.
