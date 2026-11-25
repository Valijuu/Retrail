# Changelog

What changed for riders, per release. Every user-visible change adds a line under **Unreleased** in the
same commit; at release time the section gets the version and date and is the source for the store
release notes (`docs/play-store.md` § Release notes, style rules there). Internal work (tests, CI,
store graphics, refactors) stays out.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions as in `pubspec.yaml`.

## Unreleased

### Changed
- Android: your rides, route previews and profile photo are no longer part of the Google cloud backup. A new phone gets your name and settings back, but not the ride history, unless you transfer directly from the old phone (Android 12 and newer).

### Fixed
- If your rides cannot be opened when the app starts, you now see a message with "Try again" instead of a screen that never goes away (#139).
- If the recording service cannot start, the ride screen closes instead of sitting there without recording (#141).
- Choosing a profile photo shows a message when photo access is denied instead of doing nothing, and no longer leaves temporary files behind (#145).
- The place search no longer stays on "loading" after a network or certificate error; it says it is unavailable (#145).
- Ending a ride from the lock screen or the notification and then opening the app no longer starts a new ride (#152).
- The profile photo no longer turns black after an app update on iPhone; an unreadable photo shows the blank avatar (#134).
- Following a route: a stretch you ride twice is drawn once and no longer looks darker (#57).
- The name field in the first start no longer counts leading spaces toward the 30 characters (#123).

## 1.5.0+17 — 2026-11-19

### Fixed
- Phones without a portrait-only flag are no longer excluded from the Play Store listing; the app still runs in portrait only.

### Added
- Rides now record the height: the ride screen shows the running ascent and descent, the history card shows the
  ascent (or the descent for snowboard and ski), and the ride detail shows both. Older rides and rides
  without height data show nothing (#97).
- The History tab has a Map view next to the list: all your rides at once as lines in the colour of their
  activity, or as a heatmap, with an activity menu to tick the activities you want to see. Tap a line to see one card: the best
  ride of that route, with its best time and a count that opens all rides of the route; the tapped ride shows
  its direction and its start and finish on the map. The location button sets the pin and shows its whole
  5 km circle with some room around it. Press and hold the map (or use
  the location button) to set a pin and show only the rides within 1 to 50 km of it (#96).
- Search a place by name on the map (magnifier next to the activity menu) and set the pin there; the
  typed text goes to Photon (OpenStreetMap data) only while you use it (#106).

### Changed
- The map opens on your own activity from Settings (you can still tick others on and off). Its activity menu
  works on the map only and leaves the History list alone, and an entry ticks or unticks all activities at
  once. The pin with its radius works on the map only as well (#96).
- The map's activity menu lists every activity, dimming those without rides (#113).
- On the map, the search and filters at the top only act where they make sense: the activity filter and the sort
  order stay with the list, and the filter menu shows only year, months, favourites and routes there. The
  activity button shows how many routes the map draws ("12 of 40 routes"); rides on the same line count as one route, also without "follow", whether
  the search, the filters, the activity menu or the pin's radius hide the rest (#113).
- On the map, Back closes the open menu, place search or ride card first instead of leaving the tab (#115). The
  keyboard no longer pops up again after the filter sheet, a route group or a found place closes, and the
  place search takes the typing from the header search (#116, #117). With a pin set, typing a search no longer
  zooms the map away from the circle (#121).
- The map keeps rides and the pin's circle clear of the buttons on top when it frames them, frames the rides again after the pin is removed, and frames them after a filter changed in the list (#118).
- Clearing a search on the map brings the lines back at once instead of blinking while they are drawn again (#127).
- The History tab shows the List/Map switch and the map also before your first ride, with a note "No rides yet", so you see the map is there (#122).
- Place names on every map and in the ride previews follow the app language: German names in the German app instead of English ones, also for places written in another script, which show the German name above it (#128, #131). Previews are drawn again once per language.
- The route comparison lists the fastest follow first and shows the top speed next to the average.
- The tabs no longer change by swiping sideways, only through the bar at the bottom, so maps can be
  panned and pinched freely.

## 1.4.0+15 — 2026-11-10

### Added
- Snowboard and ski are new activities, with their own icons, for rides in winter (#94).

## 1.3.3+14 — 2026-11-09

### Changed
- Retrail has a new app icon: the orange R with the route pin on a dark brown tile, on Android and
  iPhone, larger on the home screen. It also shows on the welcome step, the Android start screen and
  the iPhone Live Activity. Android 13+ themed icons are supported.
- The countdown voice is now a fixed, natural recorded voice in German and English instead of the
  phone's system voice. It sounds the same on every phone, starts without delay and no longer reads
  odd text on iPhones (#81).

### Fixed
- Android: while recording, the status bar shows a white Retrail R instead of a blank blob.
- Profile: the photo chooser is centred under the avatar again.
- Ride previews: a map tile that fails to draw no longer breaks the preview, and a ride card no longer
  shows a broken image when its preview is requested twice at once (#88).

### Added
- iOS: the app is prepared for the App Store (signing, privacy manifest, iOS 15 minimum).

## 1.3.1+8 — 2026-10-30

First public release on Google Play. Summary in `docs/play-store.md` § Release notes.
