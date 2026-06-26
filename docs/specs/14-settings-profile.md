# Spec 14 — Settings & profile

**Status:** DONE — implemented test-first; 264 total tests green, analyze clean
**Phase:** 14 of 15
**Depends on:** Spec 2 (`themeModeProvider`/`setThemeMode`), Spec 3 (`PreferencesRepository`), Spec 9 (`ProfileAvatar`, `ProfilePhotoChooser`, `profilePhotoManagerProvider`, `currentProfilePhotoProvider`), Spec 10 (`lastActivityTypeProvider`/`saveLastActivityType`, Home top-header avatar), Spec 13 (history tab pattern for the screen header)
**Branch:** `phase/14-settings-profile`

---

## Goal

Port the original **`SettingsPage` + `SettingsViewModel`** and the **`ProfileEditSheet` +
`ProfileViewModel`**. Replace the settings placeholder tab (`MainShell` tab 2) with a real
`SettingsScreen` offering three sections — **default activity**, **language**, **appearance/theme** —
and wire the **profile edit sheet** (name + photo) to the Home top-header avatar tap.

Theme and default-activity already have providers + persistence (Specs 2/10); this spec wires the UI
and adds the one missing piece: **in-app language switching** (system / English / German), which the
Android app did via `AppCompatDelegate` but Flutter handles in-app (per the roadmap: "Flutter handles
locale in-app on both → simpler than today"). Everything is `analyze` + `test` green — no device-gated
pieces (the photo picker/cropper seam from Spec 9 is already faked in tests).

---

## A. Language / locale (the one piece of new infrastructure)

### Data layer — `PreferencesRepository` (additive)
Add a `language` preference (stored string `system`/`en`/`de`, default `system`), mirroring the
existing `themeMode` pattern:
```dart
Stream<String> get language;          // default 'system'
Future<void> setLanguage(String tag); // 'system' | 'en' | 'de'
```
(New key, additive — no existing signatures change.)

### `lib/features/settings/settings_providers.dart`
```dart
enum AppLanguage { system, english, german }   // tags: null / 'en' / 'de'

AppLanguage appLanguageFromTag(String tag);    // 'en'→english, 'de'→german, else system
Locale? localeFor(AppLanguage l);              // system→null, english→Locale('en'), german→Locale('de')

final appLanguageProvider = StreamProvider<AppLanguage>(...);   // prefs.language → enum
final localeProvider = Provider<Locale?>(...);                  // appLanguageProvider → Locale?
```

### App wiring — `lib/app.dart`
Add `locale: ref.watch(localeProvider)` to `MaterialApp.router` (null = follow system). Selecting a
language rewrites the pref → `localeProvider` updates → the whole app re-localizes immediately, exactly
as the original's configuration-change did. No `AppCompatDelegate`, no Android per-app-locale APIs.

---

## B. Settings controller — `SettingsController` (`settings_providers.dart`)

A thin, testable seam over the prefs setters (mirrors `SettingsViewModel`), so the screen stays
declarative and the writes are unit-testable. **DataStore is the single source of truth** — the screen
reads the live providers (`themeModeProvider`, `appLanguageProvider`, `lastActivityTypeProvider`) and
the controller only writes back:
```dart
class SettingsController {
  Future<void> setTheme(ThemeMode mode);          // prefs.setThemeMode('system'|'light'|'dark')
  Future<void> setLanguage(AppLanguage language); // prefs.setLanguage('system'|'en'|'de')
  Future<void> setDefaultActivity(ActivityType);  // prefs.saveLastActivityType(type.id)
}
```
No new persistence beyond the `language` key; theme/activity reuse existing setters.

---

## C. Settings screen — `lib/features/settings/settings_screen.dart` (ports `SettingsPage`)

A `ConsumerWidget`, vertically scrollable, on `colors.surface`. Header `navSettings` (titleLarge,
matching the History header). Three sections, each a `_SectionHeader` (uppercase `subtleText` label +
`onSurfaceVariant` subtitle) followed by rows:

1. **Default activity** (`settingsSectionActivity` / `settingsActivitySubtitle`): an
   **`_ActivitySummaryRow`** — activity icon + label (from `lastActivityTypeProvider` via
   `ActivityTypeUi`) + chevron, 12dp `surfaceContainer` pill, tap → activity picker dialog.
2. **Language** (`settingsSectionLanguage` / `settingsLanguageSubtitle`): three **`_OptionRow`**s
   (System default / Deutsch / English) → `controller.setLanguage(...)`, selection from
   `appLanguageProvider`.
3. **Appearance** (`settingsSectionTheme` / `settingsThemeSubtitle`): three `_OptionRow`s
   (System default / Light / Dark) → `controller.setTheme(...)`, selection from `themeModeProvider`.

- **`_OptionRow`**: full-row selectable (Material `Radio` reflects state only; whole row toggles),
  selected row gets a `surfaceContainer` background, `Radio` tinted `primary`. Semantics:
  `Role.radio` equivalent (`Radio` + `MergeSemantics`).
- **Activity picker dialog** (`_ActivityPickerDialog`, title `settingsActivityDialogTitle`): a grid of
  `ActivityType`s (reuse the onboarding **`ActivityTile`** widget), current one preselected; selecting
  closes + `controller.setDefaultActivity(type)`. Mirrors the original `ActivityPickerDialog`.

---

## D. Profile edit sheet — `lib/features/profile/profile_edit_sheet.dart` (ports `ProfileEditSheet`)

> **Faithful to the Flutter port's photo model, not the Android avatar-index model.** Spec 9 replaced
> the Android predefined-avatar grid + `avatarIndex` with a **photo-based** model (current photo +
> last-5 recents, `ProfilePhotoManager`). The edit sheet reuses those exact widgets so onboarding and
> settings stay consistent (`ProfilePhotoChooser`'s doc already says "Reused by onboarding + Settings").

A `showModalBottomSheet` content (`ConsumerStatefulWidget`):
- Title `profileEditTitle`.
- **Name** field (≤30 chars) in a `surfaceContainer` rounded box, seeded from `userName`
  (`profileEditNameLabel` / reuse `initNameLabel`).
- **`ProfileAvatar`** (current photo) + **`ProfilePhotoChooser`** (upload slot + recent photos,
  select/delete) — photo changes persist **live** via `ProfilePhotoManager` (as the original's
  custom-photo path did).
- **Cancel** / **Save** pills. Save writes the **name** (`prefs.saveUserName`) and dismisses; the photo
  is already persisted. (No `avatarIndex` — that concept doesn't exist in the Flutter port.)

A small `profileEditControllerProvider` (or reuse `profilePhotoManagerProvider` + a `saveName`
wrapper) keeps the name write testable.

---

## E. Shell wiring — `lib/features/shell/main_shell.dart`

- Replace `const _PlaceholderTab(label: 'settings')` (tab 2) with `const SettingsScreen()`.
- Pass `onAvatarTap` to `HomeScreen` → `showModalBottomSheet(... ProfileEditSheet())`. (The Home
  top-header avatar already exposes `onAvatarTap`; it's currently unwired.)

No router changes.

---

## Localization — new ARB keys (`app_en.arb` + `app_de.arb`)

Mirror the Android `settings_*`, `profile_edit_*`, `a11y_*` strings.

| Key | EN | DE |
|---|---|---|
| `settingsSectionActivity` | `Activity` | `Aktivität` |
| `settingsActivitySubtitle` | `Pre-selected when you start a ride.` | `Wird beim Start einer Fahrt vorausgewählt.` |
| `settingsActivityDialogTitle` | `Default activity` | `Standardaktivität` |
| `settingsSectionLanguage` | `LANGUAGE` | `SPRACHE` |
| `settingsLanguageSubtitle` | `Choose the language for the app interface.` | `Sprache für die App-Oberfläche wählen.` |
| `settingsLanguageSystem` | `System default` | `Systemsprache` |
| `settingsLanguageGerman` | `Deutsch` | `Deutsch` |
| `settingsLanguageEnglish` | `English` | `English` |
| `settingsSectionTheme` | `THEME` | `DARSTELLUNG` |
| `settingsThemeSubtitle` | `Choose the app appearance.` | `Darstellung der App wählen.` |
| `settingsThemeSystem` | `System default` | `Systemstandard` |
| `settingsThemeLight` | `Light` | `Hell` |
| `settingsThemeDark` | `Dark` | `Dunkel` |
| `a11yChangeActivity` | `Change activity type` | `Aktivität ändern` |
| `a11ySettingsScreen` | `Settings screen` | `Einstellungen-Bildschirm` |
| `profileEditTitle` | `Edit profile` | `Profil bearbeiten` |

**Already present — reuse:** `navSettings`, `initNameLabel` ("Name"), `actionCancel`, `actionSave`,
`actionContinue`/`actionSkip`, the `profilePicture*` chooser strings (upload/delete/subtitle), and the
`activity*` names. (The Android `profile_picture_title`/`profile_own_photo`/`profile_remove_photo`
belong to the avatar-grid model the Flutter port doesn't use; the photo chooser supplies its own.)

---

## Test-first plan (`test/settings/`, `test/profile/`)

**`settings_providers_test.dart`** (pure): `appLanguageFromTag` mapping (`en`/`de`/other→system);
`localeFor` (system→null, english→`en`, german→`de`).

**`settings_controller_test.dart`** (in-memory prefs): `setTheme`/`setLanguage`/`setDefaultActivity`
write the expected pref values (assert via the repo's streams).

**`settings_screen_test.dart`** (widget; override `themeModeProvider`, `appLanguageProvider`,
`lastActivityTypeProvider`, fake `SettingsController`):
- Renders the three section headers + option rows + the activity summary row.
- The selected theme/language row shows the radio selected (from the stubbed providers).
- Tapping a theme row / language row calls the controller with the right value.
- Tapping the activity row opens the picker; choosing a tile calls `setDefaultActivity`.

**`profile_edit_sheet_test.dart`** (widget; stub `currentProfilePhotoProvider`/`recentProfilePhotosProvider`,
fake photo manager + a name-save spy):
- Renders the title, the name field seeded from `userName`, the avatar + chooser.
- Editing the name + Save writes the new name; Cancel dismisses without saving.

**`app_locale_test.dart`** (widget): overriding `localeProvider` with `Locale('de')` makes the app
render German strings (e.g. a known DE label), and `Locale('en')` renders English — proves the
`locale:` wiring re-localizes.

All gated by `flutter analyze` clean + full suite green before the phase is done.

---

## Acceptance

- Settings tab shows the three sections; theme + language + default-activity selections persist and
  take effect immediately (theme recolors, language re-localizes the whole app, default activity
  preselects the next ride).
- Home avatar tap opens the profile edit sheet; name + photo edits persist (photo live, name on Save).
- `flutter analyze` clean; full suite green.

---

## Out of scope (later / deferred)

- The image picker/cropper device behavior (already a faked seam since Spec 9; device-verified in Spec 15).
- App icon, branding, permissions/Info.plist, integration tests, release pass → **Spec 15**.
