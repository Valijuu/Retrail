# Changelog

What changed for riders, per release. Every user-visible change adds a line under **Unreleased** in the
same commit; at release time the section gets the version and date and is the source for the store
release notes (`docs/play-store.md` § Release notes, style rules there). Internal work (tests, CI,
store graphics, refactors) stays out.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions as in `pubspec.yaml`.

## Unreleased

### Changed
- Retrail has a new app icon, on Android and iPhone, with a larger R on the home screen. It also
  shows on the welcome step, the Android start screen and the iPhone Live Activity. Android 13+
  themed icons are supported.
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
