# Changelog

What changed for riders, per release. Every user-visible change adds a line under **Unreleased** in the
same commit; at release time the section gets the version and date and is the source for the store
release notes (`docs/play-store.md` § Release notes, style rules there). Internal work (tests, CI,
store graphics, refactors) stays out.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions as in `pubspec.yaml`.

## Unreleased

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
  order stay with the list, the filter menu shows only year, months, favourites and routes there, and a line
  "12 of 40 rides" shows when the map hides rides, whether by these filters, the activity menu or the pin's
  radius (#113).
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
