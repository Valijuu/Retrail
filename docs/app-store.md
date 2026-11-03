# Apple App Store: preparation and release plan

Counterpart to `docs/play-store.md`. Android is in production; this file tracks what iOS
needs. Keep it in sync with `site/privacy/index.html` and the privacy manifest
(`ios/Runner/PrivacyInfo.xcprivacy`).

## Status

| Done in the repo | Needs the paid Apple account | Needs a person |
|---|---|---|
| iPhone only (`TARGETED_DEVICE_FAMILY = 1`, no iPad orientations) | Apple Developer Program (99 USD/year) | iPhone screenshots 6.9" |
| Privacy manifest (no tracking, coarse location for map tiles) | App ID `io.github.valijuu.retrail` + `…RideActivity` | App Store texts pasted into App Store Connect |
| `ITSAppUsesNonExemptEncryption = false` | Distribution certificate + App Store profiles (app + extension) | Age rating, privacy label, review notes |
| Live Activity extension already embedded | App Store Connect API key, then CI signing + upload | Device test of the signed build (TestFlight) |

Until the account exists, `tool/ios_fetch_build.sh` (free Apple ID, 7-day signature) stays the
only way to run the app on an iPhone. It cannot upload to the App Store.

## Release path without a Mac

There is no Mac, so signing and upload run on the GitHub macOS runner, like the unsigned build.

1. Create the App IDs and a distribution certificate in the Developer portal. The certificate
   request can be made on Linux with `openssl`.
2. Create an **App Store Connect API key** (role App Manager). Store key id, issuer id and the
   `.p8` as repository secrets, never in the repo.
3. A new workflow (`ios-release.yml`, manual trigger only) builds `flutter build ipa
   --export-options-plist …`, signs both targets with the stored profiles and uploads to
   TestFlight (`xcrun altool --upload-app` with the API key).
4. Test the TestFlight build on the iPhone, then submit it for review in App Store Connect.

The unsigned CI build stays as the compile gate.

Workflow: `.github/workflows/ios-release.yml` (manual; the input `upload` off signs and checks the
.ipa without uploading). It signs the app and the Live Activity extension with manual signing:
`tool/ios_release_signing.py` switches only the two Release configurations on the runner, the
committed project keeps automatic signing. The build number comes from `pubspec.yaml`
(`version: x.y.z+N`); TestFlight rejects a build number it has seen, so bump N before each run.
Not run yet: the first run needs the account setup below, and `altool` and the export options
are unverified until then.

### CI secrets (repository secrets, set once by hand)

Create them in a real terminal (`gh secret set NAME < file`), never through the chat or into the repo.

| Secret | What it is |
|---|---|
| `APPLE_TEAM_ID` | Team ID (Developer portal → Membership details) |
| `IOS_DIST_CERT_P12_BASE64` | Apple Distribution certificate with its private key as `.p12`, base64 |
| `IOS_DIST_CERT_PASSWORD` | the password chosen for that `.p12` |
| `IOS_PROFILE_APP_BASE64` | App Store profile for `io.github.valijuu.retrail`, base64 |
| `IOS_PROFILE_EXT_BASE64` | App Store profile for `io.github.valijuu.retrail.RideActivity`, base64 |
| `ASC_KEY_ID`, `ASC_ISSUER_ID` | App Store Connect API key id and issuer id |
| `ASC_API_KEY_P8` | content of the downloaded `AuthKey_<id>.p8` |

On Linux: `base64 -w0 file` gives the base64 value. The certificate request is made with
`openssl req -new -newkey rsa:2048 -nodes -keyout retrail_dist.key -out retrail_dist.csr -subj
"/CN=Retrail Distribution/emailAddress=…"`. After downloading the `.cer`:
`openssl x509 -inform DER -in distribution.cer -out dist.pem`, then
`openssl pkcs12 -export -inkey retrail_dist.key -in dist.pem -out dist.p12 -certpbe PBE-SHA1-3DES
-keypbe PBE-SHA1-3DES -macalg sha1` (the old algorithms keep macOS `security import` able to read it).

## Privacy label (App Store Connect → App Privacy)

Same facts as the Play Data safety form: map tile requests to OpenFreeMap leave the device,
and they reveal the viewed area. The only other request is the connectivity probe
(`https://clients3.google.com/generate_204`, no payload, named in the privacy policy); it carries
no data type of Apple's list. Rides, GPS points, profile photo and settings stay on the device.
"Navigate to start" hands a coordinate to a maps app the user picks; that is not collection by
Retrail. Checked against the code on 2026-11-03.

| Question | Answer |
|---|---|
| Data collected | **Coarse Location** only |
| Linked to the user | No |
| Used for tracking | No |
| Purpose | App Functionality |

Privacy policy URL: https://valijuu.github.io/Retrail/privacy/ (names iOS, Apple, the Live Activity
and the connectivity probe; checked 2026-11-03).

## App Review notes (draft)

> Retrail records skate and longboard rides with GPS. No account or login is needed.
> Location (While Using, then Always) is used for recording the route while the screen is off;
> recording only runs after the user starts a ride and shows the system location indicator.
> The audio background mode is used only to speak the 5-second countdown before a ride starts
> (text-to-speech, no music or recording). A Live Activity on the lock screen shows the running
> ride with Pause/Stop buttons. To test without moving: Xcode/Simulator, Features → Location →
> City Run, then start a ride from Home.

Apple often questions `location` and `audio` background modes. The notes above are the answer.

## Age rating

No objectionable content, no web access beyond the map, no user-generated content shared:
expected **4+**. Fill the questionnaire in App Store Connect with "None" everywhere.

## Listing

- Name, subtitle (30), promotional text, description, keywords (100 characters, comma
  separated): derive from the Play texts in `store/play/text/` and shorten. Keep the note that the
  countdown voice is synthetic (Microsoft Azure); Microsoft's TTS terms ask for that disclosure (#90). Apple has a keyword
  field, so the keyword list replaces the Play keyword table.
- Category: Sports (secondary: Health & Fitness).
- Screenshots: 6.9" iPhone (1320 × 2868) is required, the rest are scaled from it. German and
  English sets. Never use real routes (see the repo rule on location data).
  There is no Mac, so the shots come from the iOS Simulator on the GitHub macOS runner:
  workflow `ios-screenshots.yml` (manual) builds the demo databases and a simulator app and runs
  `tool/ios_screenshots.sh` (invented Tempelhofer Feld rides, 9:41 status bar, light and dark,
  `1320 × 2868` checked). The Play shots (1080 × 1920, Android UI) cannot be reused, only their motive
  list in `store/play/screenshots.tsv` and the framing idea.
  **Motives:** the home screen comes from a plain launch with seeded prefs and database. The Play set
  (history, detail, comparison sheet, follow route, countdown, live ride, activity picker, plus the
  ride in dark) comes from `integration_test/store_screenshots_test.dart`, run by the script with
  `flutter test -d <udid>`: it navigates the real app with provider overrides (mock prefs, a copy of
  the demo database, the newest demo ride replayed as GPS, no Live Activity, silent countdown) and
  prints `RETRAIL_SHOT <name>`; the script takes the shot (`simctl io screenshot`, the map is a native
  view the test cannot capture) and writes an ack file into the app's Documents. Each shot is checked
  for size and for a known text per screen (Vision OCR). The Live Activity on the lock screen is not
  automated. Framing: `tool/render_ios_store_graphics.sh` and `store/ios/screenshot_frame.html`
  (1320 × 2868, motives and captions in `store/ios/screenshots.tsv`, the same 8 as Play).
- Support URL and marketing URL: the GitHub Pages site. Support contact: retrail.app@proton.me.
- Price: free. Paid features later need the Paid Apps agreement and the trader status (#67).

## Screenshot automation: where we stopped (2026-11-03)

Tracked in #87, branch `feature/ios-screenshots`. The workflow captures all 8 Play motives in
German and English (run 41638376581, every shot checked by eye): history, detail, comparison sheet,
follow route ("km to go"), countdown, live ride, activity picker, and the ride in dark. Not
automated: the Live Activity on the lock screen. Before the merge: remove the temporary push
trigger from `ios-screenshots.yml`, then frame the shots with `tool/render_ios_store_graphics.sh`.

## Open points

- Trader status (DSA) is asked in App Store Connect for EU distribution (#67).
- Live Activity buttons need iOS 17 and cannot be tested on the iPhone 8 (iOS 16.7); check them
  on a newer device or the Simulator before submitting.
- Deployment target: the app is iOS 15.0 (Apple requires 15.0+ for uploads from April 2027,
  ITMS-90068), the extension is 16.1.
