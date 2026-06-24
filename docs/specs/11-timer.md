# Spec 11 — Timer / countdown screen

**Status:** DONE — merged to `main`; 188 total tests green, analyze clean
**Phase:** 11 of 15
**Depends on:** Spec 4 (`ActivityType`), Spec 8 (router `/timer` → `/ride`), Spec 9 (`ActivityTypeUi`), Spec 10 (`lastActivityTypeProvider`, start-tracking flow lands here)
**Branch:** `phase/11-timer`

---

## Goal

Port the original **TimerPage + TimerViewModel** verbatim in behavior: a 5→0 second
countdown shown as an animated ring, a read-only chip of the activity type about to be
recorded, a **+5 sec.** action, a static GPS-signal indicator, and a **Start now** button.
When the countdown reaches 0 (or the user taps **Start now**), navigate to the active-ride
map screen (`/ride`, currently a placeholder — recording itself begins in Spec 12).

This is the bridge between Home's start-tracking flow and the active-ride screen. It does
**not** start the `RideTracker` — it only counts down and navigates, exactly as the Android
`TimerPage` does (recording starts on the map screen). The pending activity type was already
recorded by Home's `beginTracking` in Spec 10.

---

## Logic — `lib/features/timer/countdown_timer.dart` (ports `TimerViewModel`)

A plain, Riverpod-free, fake-async-testable class — same seam as `RideTracker`.

```dart
class CountdownTimer extends ChangeNotifier {
  int get value;          // seconds remaining; starts at 5
  bool get isFinished;    // value == 0

  void start({int from = 5});  // (re)starts: sets value=from synchronously, then ticks
  void addTime(int seconds);   // restart at current value + seconds
  void stop();                 // cancel ticking, hold current value
  // dispose() cancels the timer.
}
```

Behavior, matched to `TimerViewModel`:
- `start(from)` cancels any running ticker, sets `value = from` **synchronously** and notifies
  (mirrors the original's eager first emission), then every 1000 ms decrements by 1 down to 0.
- At 0 it stops ticking and holds (no negative values); `isFinished` becomes true.
- `addTime(s)` calls `start(value + s)` — so it restarts the ring from the new total.
- `stop()` cancels the ticker; `value` is frozen.
- Uses a `Timer.periodic` internally (driven by `fake_async` in unit tests and by
  `tester.pump(Duration)` in widget tests — a finite countdown, so no stream-style hang).

### Provider seam

The countdown is screen-scoped (its lifecycle matches the original `LaunchedEffect(Unit)`),
so the screen **owns** the `CountdownTimer` in its `State` (created in `initState`, disposed in
`dispose`) rather than a long-lived provider. The activity-type chip reads the existing
`lastActivityTypeProvider` (Spec 10). No new provider is required.

---

## Screen — `lib/features/timer/countdown_screen.dart` (ports `TimerPage`)

A `ConsumerStatefulWidget`. On `initState` it creates a `CountdownTimer` and calls `start()`.
It listens to the timer; when `isFinished` flips true it navigates to `/ride` (once). A
`Start now` press stops the timer and navigates immediately.

Layout (top-centred block + bottom action block), mirroring the original:
- **Label** `timerGetReady` (uppercase "GET READY"), dimmed.
- **Activity chip** (`_ActivityChip`): pill, dark container, activity icon + label from
  `ActivityTypeUi`. Read-only.
- **Countdown ring** (`_CountdownRing`, `CustomPainter`): a 180 dp ring — a full track circle
  plus a `Primary` arc sweeping `360° × value/total` from the top (−90°), round stroke cap,
  10 dp stroke. Arc progress animates over ~1000 ms (`TweenAnimationBuilder`). The centre digit
  is the current `value`, swapped with a vertical slide (`AnimatedSwitcher` + `SlideTransition`).
  `total` is the highest value seen this run (so +5 keeps the ring proportional), as in the original.
- **+5 chip** (`_AddTimeChip`): tappable pill → `timer.addTime(5)`. Label `timerAddFiveSec`.
- **Tagline** `timerTagline` (two lines, centred), dimmed.
- **Bottom block:** static **GPS status row** (`_GpsStatusRow`: dot + `gpsStatusLabel` +
  `gpsStatusReady`) then the **Start now** pill button (`timerStartNow`).

### Fixed dark palette (faithful to the original)

The Android `TimerPage` references raw color constants, not theme-resolved ones: dark
**surfaces** with light-theme **accents**, regardless of the app's current theme. Reproduce
this with a fixed palette built from the existing tokens — **no new hex**:

| Element | Token |
|---|---|
| Screen background | `AppColors.dark.surface` (DarkSurface `#1C1B1F`) |
| Ring track / chips / GPS row bg | `AppColors.dark.surfaceContainer` (`#2B2118`) |
| Ring arc + GPS dot + Start-now bg | `AppColors.light.primary` (Primary `#B45309`) |
| Centre digit | `AppColors.light.surface` (`#FFF8F5`) |
| Labels (get-ready, tagline, GPS label) | `AppColors.light.onSurfaceVariant` (`#857470`) |
| Chip icon/text + GPS "ready" | `AppColors.light.primaryContainer` (`#FFEDD5`) |
| Start-now text | `AppColors.light.onPrimary` (`#FFF8F5`) |

The screen does **not** read `Theme.of(context).extension<AppColors>()` — it uses these two
fixed constants directly so the countdown always looks the same in light or dark mode.

---

## GPS status indicator (faithful: static)

The original `GpsStatusRow` is **purely static** — it always shows a green dot + "GPS signal
ready"; there is no real readiness logic in the Android app. We reproduce it as static. Real
permission/GPS-readiness gating is `RideStartGate` (Spec 5 Part B, deferred) and already runs
*before* navigation into this screen, so the indicator here stays static and faithful.

---

## Router/shell wiring — `lib/features/shell/app_router.dart`

Replace the `/timer` placeholder with `CountdownScreen`, keeping the existing fade transition:

```dart
GoRoute(path: AppRoutes.timer,
    pageBuilder: (c, s) => _fade(const CountdownScreen(), s)),
```

No redirect changes. `/ride` stays the placeholder until Spec 12.

---

## Localization — new ARB keys (`app_en.arb` + `app_de.arb`)

| Key | EN | DE |
|---|---|---|
| `timerGetReady` | `GET READY` | `FERTIG MACHEN` |
| `timerTagline` | `Ride starts soon.\nStay balanced.` | `Fahrt beginnt gleich.\nBleib in Balance.` |
| `timerStartNow` | `Start now` | `Jetzt starten` |
| `timerAddFiveSec` | `+5 sec.` | `+5 Sek.` |
| `gpsStatusLabel` | `GPS signal` | `GPS-Signal` |
| `gpsStatusReady` | `ready` | `bereit` |

(These mirror the Android `timer_*` / `gps_status_*` strings 1:1.)

---

## Test-first plan (`test/timer/`)

**`countdown_timer_test.dart`** — ports the four `TimerViewModelTest` cases via `fakeAsync`:
1. `counts down to 0` — `start()`, advance 5 s → `value == 0`, `isFinished`.
2. `stop freezes the value` — `start()`, advance 1.5 s (→ 4), `stop()`, advance 10 s → still 4.
3. `addTime increases the value immediately` — `start()` (→ 5), `addTime(5)` → `value == 10`.
4. `addTime keeps counting down` — `start()` + `addTime(5)` (→ 10), advance 11 s → `value == 0`.
   Plus: notifies listeners on each change; `dispose` cancels the ticker.

**`countdown_screen_test.dart`** — widget tests (bounded pump; finite countdown):
- Renders `GET READY`, the activity chip label (from an overridden `lastActivityTypeProvider`),
  initial digit `5`, the tagline, and the GPS row (`GPS signal` / `ready`).
- Tapping **+5 sec.** shows `10`.
- Tapping **Start now** navigates to `/ride` (asserts the placeholder `ride` text).
- Pumping 5 s with no interaction auto-navigates to `/ride`.

---

## Acceptance

- All four ported countdown cases green; widget tests green.
- `flutter analyze` clean; full suite green.
- Countdown looks/behaves like the original (always-dark palette, animated ring, sliding digit,
  +5, static GPS row), and both 0-reached and Start-now reach `/ride`.

---

## Out of scope (later specs)

- Starting the actual `RideTracker` recording → **Spec 12** (active-ride map screen).
- Real GPS/permission readiness (`RideStartGate` real impl) → **Spec 5 Part B** (deferred).
- Live GPS-signal strength on this screen — the original is static; not added.
