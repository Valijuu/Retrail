# Spec 9 — Onboarding (name → photo → activity)

**Status:** DONE — merged to `main`; 162 total tests green, analyze clean.
**Phase:** 9 of 15
**Depends on:** Spec 3 (`PreferencesRepository`), Spec 4 (`ActivityType`), Spec 8 (routes/shell)

## Goal
Build the three onboarding screens and their state, replacing the Spec 8 placeholders. Completing the flow writes prefs and sets `onboardingDone`. Also introduces a reusable **profile-photo component** (blank default, last-5 photos, delete) used here and later by Settings.

## Flow (mirrors the original)
`init` (name) → `profilePicture` (optional) → `activityPicker` (**finishes onboarding**) → main.
- `init`: "Let's go" **and** "Skip" both advance (name saved only if non-blank, trimmed).
- `profilePicture`: "Continue"/"Skip" both advance; does **not** finish onboarding.
- `activityPicker`: "Continue" saves the chosen activity as `lastActivityType` **and** sets `onboardingDone`.

## Decided
- **Activity icons + illustration:** Material-icon stand-ins (e.g. longboard→`skateboarding`, skateboard→`skateboarding`, rollerblades/rollerskates→`roller_skating`, mountainboard→`downhill_skiing`/`terrain`, scooter→`electric_scooter`, other→`more_horiz`); Material illustration for the init screen. Exact custom SVGs can be recreated in polish (Spec 15) if wanted.

## Profile-photo feature (NEW — replaces the preset avatar)
No preset avatar. The profile picture is **blank by default** (neutral placeholder circle — person glyph). The user may set a photo or not. The **last 5 photos** are kept and selectable, each deletable.

### Data model (extends `PreferencesRepository`, Spec 3)
- Drop `avatarIndex`. Replace single `customPhotoPath` with:
  - `currentProfilePhoto: Stream<String?>` — selected photo path, or null (blank).
  - `recentProfilePhotos: Stream<List<String>>` — up to 5 paths, newest first (stored as a JSON string under `profile_photos`).
- Writers: `setCurrentProfilePhoto(path?)`, `addRecentProfilePhoto(path)` (prepend, cap 5), `removeRecentProfilePhoto(path)`.

### `ProfilePhotoManager` — `lib/features/profile/profile_photo_manager.dart`
Coordinates files + prefs (reusable by onboarding & Settings):
- `addNewPhoto()` → runs `ProfilePhotoPicker` (pick+crop+save to app files); on success: `addRecentProfilePhoto` + `setCurrentProfilePhoto`; if adding pushes a 6th out, **delete the evicted file**.
- `select(path)` → `setCurrentProfilePhoto(path)`.
- `delete(path)` → `removeRecentProfilePhoto(path)` + delete the file; if it was current, clear current (→ blank).
- `clear()` → current = null (stays in recents).

### `ProfilePhotoPicker` — `lib/features/profile/profile_photo_picker.dart`
`abstract interface class ProfilePhotoPicker { Future<String?> pickAndCrop(); }` — real impl uses `image_picker` + `image_cropper` (1:1, 512², q85), saves to app files, returns the path. Interface seam → fake in tests; real picker device-verified.

### `ProfileAvatar` widget — `lib/features/profile/profile_avatar.dart`
Renders the current photo (circle, optional ring) or a neutral placeholder when blank. Reused by onboarding, Home header, Settings.

### `ProfilePhotoChooser` widget — `lib/features/profile/profile_photo_chooser.dart`
The selectable row: upload slot (`AddAPhoto`) + the recent photos (selected = primary ring); each recent has a small delete affordance (long-press or a corner ✕). Used by the onboarding photo screen and the Settings profile editor.

## Onboarding state — `lib/features/onboarding/onboarding_providers.dart`
Ports `InitViewModel`:
- `nameInputProvider` (Notifier<String>): `onChange` ignores input > 30 chars.
- `saveName()` — trims; saves `saveUserName` only if non-empty.
- `finishOnboardingWithActivity(ActivityType)` — `saveLastActivityType(type.id)` + `setOnboardingDone()`.

## Screens — `lib/features/onboarding/`
- `init_screen.dart` — illustration, title + subtitle, name `TextField` (singleLine, words-capitalization, max 30), live `N/30` counter, primary "Let's go" + "Skip"; both saveName → `profilePicture`. Tokens: radius-12 input, radius-50 pill.
- `profile_picture_screen.dart` — named/anon greeting, 140dp `ProfileAvatar` preview (blank placeholder if none), `ProfilePhotoChooser`, Continue/Skip → `activityPicker`.
- `activity_init_screen.dart` — title + hint, 2-column grid of all 7 `ActivityType` tiles (Longboard preselected), Continue → `finishOnboardingWithActivity` → main (clears the onboarding stack).
- `activity_tile.dart` — reusable selectable tile (Material icon + label; selected = primary border/container). Reused by Settings + the home picker.

## Router wiring
Replace the `init`/`profilePicture`/`activityPicker` placeholders with the real screens; keep fades + stack-clearing on completion.

## Localization
Add to `app_en.arb`/`app_de.arb`: `initWelcomeTitle`, `initNameQuestion`, `initNameLabel`, `initNamePlaceholder`, `actionLetsGo`, `actionSkip`, `actionContinue`, `profilePictureGreetingNamed` (`{name}`), `profilePictureGreetingAnon`, `profilePictureSubtitle`, `profilePictureUploadCd`, `profilePictureDeleteCd`, `activityPickerTitle`, `initActivityHint`, the 7 `activity*` labels, a11y strings. German per the reference table.

## Test-first plan (`test/onboarding/`, `test/profile/`)
1. `onboarding_state_test.dart` — `onChange` caps at 30; `saveName` trims + skips empty (mock prefs); `finishOnboardingWithActivity` → `saveLastActivityType('LONGBOARD')` + `setOnboardingDone`.
2. `profile_photo_manager_test.dart` — `addNewPhoto` (fake picker) sets current + prepends recent; a 6th photo evicts + **deletes** the oldest file; `select` sets current; `delete` removes from recents + deletes file + clears current if selected; blank default.
3. `prefs_profile_photos_test.dart` — recent list round-trips JSON, caps at 5; current photo persists/clears.
4. `init_screen_test.dart` — typing updates `N/30`; >30 rejected; "Let's go" saves name + routes to `profilePicture`.
5. `profile_picture_test.dart` — blank placeholder when no photo; fake picker → preview shows photo; selecting a recent switches current; delete removes it; Continue → `activityPicker`.
6. `activity_init_test.dart` — Longboard preselected; selecting another updates; Continue sets prefs + `onboardingDone` and lands on main (router integration, in-memory prefs).

## Acceptance
- `flutter analyze` clean; full `flutter test` green.
- Fresh launch walks name → photo → activity → main; relaunch → main. Profile photo blank unless set; last 5 selectable + deletable.
- Branch `phase/09-onboarding` rebased + fast-forwarded onto `main`, then deleted.

## Out of scope
Settings profile editor (Spec 14 — reuses `ProfilePhotoChooser`/`ProfileAvatar`), home start-tracking picker (Spec 10 — reuses `ActivityTile`), real camera/crop device verification.
