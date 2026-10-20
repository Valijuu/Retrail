# Spec 21: Countdown cue

**Status:** IMPLEMENTED, but not yet checked on a device. Approved in conversation on 2026-10-20 (#81).
**Depends on:** Spec 11 (countdown, now 10 s), Spec 14 (settings).

## Goal
During the pre-ride countdown the phone is often already in a pocket, so the rider can't see when recording starts. In the last five seconds the system voice says **"5, 4, 3, 2, 1"**, and **"Go!"** (de: „Los!“) when the ride starts. Each number comes with a short buzz, and "Go" with a long one. Only the countdown is announced. There are no other voice prompts (pause, distance, …).

## Behaviour
1. **Window.** Seconds `countdownCueFrom` (5) … 1 are spoken from the countdown tick (`countdownCueFor`). 0 is silent on the tick. "Go" comes from the ride start instead, so it is said exactly once, whether the countdown runs out or the rider taps **Start now** (then only "Go"). After **+5 sec.** the window is counted again from 5. A value seen twice in a row (a rebuild) is not repeated.
2. **Leaving** the countdown without starting — back, or Stop from the notification — cuts a phrase still being spoken. Once "Go" is said nothing more is counted, and **+5** no longer works while the ride starts.
3. **Setting.** Settings → **COUNTDOWN** → "Count down out loud" (de: „Countdown ansagen“), **on by default** (`countdown_cue_enabled`). Off means no voice and no vibration.
4. **Language.** The app language (`effectiveLocaleProvider`); a system language the app has no copy for (e.g. French) falls back to English, voice included. A bare language gets a regional voice (`de` → `de-DE`, otherwise `en-US`).
5. **Platforms.**

   | | Voice | Buzz |
   |---|---|---|
   | Android, ringer on | yes, other audio ducked (audio focus) | yes |
   | Android, silent / vibrate | **no** (`retrail/audio` → `isRingerNormal`) | yes |
   | iOS | yes, even with the mute switch on and the screen locked; music ducked | yes (Core Haptics, may not fire while locked) |

   iOS can't read its mute switch. The rider wanted the voice to work with the screen locked, which needs the `playback` audio category plus the `audio` background mode, and that category ignores the switch. To silence it, the rider turns the setting off.
6. **Best-effort.** A missing voice, TTS engine or vibrator never throws into the countdown and never delays a tick.
7. **Music.** No audio session is held while waiting: iOS only sets the category, the synthesizer activates the session per phrase (ducking music) and it is released after each phrase and on stop.

## Code
- Domain: `lib/domain/countdown_cue.dart` (`countdownCueFor`, `countdownCueFrom`), built with EXACT.
- Seam: `lib/tracking/countdown_announcer.dart`, `CountdownAnnouncer` + `PlatformCountdownAnnouncer` (`flutter_tts`, `vibration`, channel `retrail/audio` → `MainActivity.kt`).
- Timer: `countdown_cue_controller.dart` (`begin` / `onValue` / `onStart` / `end`) and `countdownAnnouncerProvider` / `countdownCueControllerProvider` in `countdown_providers.dart`. `CountdownScreen` only forwards its ticks.
- Settings: `PreferencesRepository.countdownCueEnabled`, `countdownCueEnabledProvider`, `SettingsController.setCountdownCue`, `SettingsSwitchRow` (`settings/widgets/settings_rows.dart`).
- Platform: `VIBRATE` + `TTS_SERVICE` query (Android manifest), `UIBackgroundModes` += `audio` (iOS).

## Store notes
- **Play:** `VIBRATE` is a normal permission, so no declaration is needed. Data safety is unchanged, because the system voices run on the device.
- **App Store review:** Apple may ask why the app uses the `audio` background mode. Answer: "Retrail speaks a 5-second countdown before a GPS ride recording starts. Riders usually lock the phone and put it away during the countdown; the audio background mode lets the countdown be heard with the screen locked. The app plays no other audio."

## Non-goals
Voice prompts during the ride (pause, resume, distance), custom sounds or beeps, choosing a voice.
