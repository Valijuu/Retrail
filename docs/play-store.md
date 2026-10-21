# Google Play: Data safety answers and store listing

Prepared for the first Play Console setup (#45). Keep this file in sync with
`site/privacy/index.html`: when the app starts sending data somewhere new,
update the privacy policy, this file and the Data safety form together.

---

## Data safety form

### What leaves the device (basis for every answer below)

Google counts data as **collected** when the app (or a library in it)
transmits it off the device. Data processed only on the device is not
declared. Retrail sends exactly two kinds of request:

| Request | To | What it reveals | Declare? |
|---|---|---|---|
| Map tiles, styles, fonts, sprites | OpenFreeMap (`tiles.openfreemap.org`, via Cloudflare) | IP address, user agent, **the map area being viewed** — during a ride that is the rider's surroundings | **Yes: Approximate location** (see below) |
| Connectivity probe | `clients3.google.com/generate_204` | IP address only, empty request | No — an IP address alone is not one of Play's data types, and nothing else is sent |

Everything else stays on the device: rides, GPS track points, profile name
and photo, settings, preview images (`lib/data/`, `lib/features/profile/`).
"Navigate to start" hands the start coordinates to a maps app the user picks
— a user-initiated transfer, which Play exempts from "sharing", and the app
transmits nothing itself.

**Why approximate location:** Play says location *inferred* from a request
must be declared. Tile requests follow the map, and while recording, the map
follows the rider, so the tile coordinates show roughly where the rider is.
A z14 tile is a few km² wide — "approximate" (≥ 3 km²) fits better than
"precise". Declaring it is the conservative answer; declaring nothing would
show "No data collected", which a reviewer could call inaccurate. We cannot
verify how long OpenFreeMap / Cloudflare keep request logs, so we do **not**
claim ephemeral processing.

### Answers, screen by screen

**Data collection and security**

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (all requests are HTTPS) |
| Do you provide a way for users to request that their data is deleted? | **No** — we hold no user data; everything on the device is deleted with the app or per ride in the app. (Play also offers "No" with no penalty when there is no account.) |

**Data types** — select only:

- Location → **Approximate location**

Leave everything else unselected (no personal info, no photos — the profile
photo never leaves the device, no app activity, no crash logs, no device IDs).

**Data usage and handling — Approximate location**

| Question | Answer |
|---|---|
| Is this data collected, shared, or both? | **Collected** (not shared: the tile request goes straight to the map service the app uses to draw its map, which processes it to serve the map) |
| Is this data processed ephemerally? | **No** |
| Is this data required for your app, or can users choose? | **Required** (the map cannot be turned off) |
| Why is this user data collected? | **App functionality** only |

**Privacy policy URL:** https://valijuu.github.io/Retrail/privacy/

Resulting store label: "This app may collect these data types: Location ·
Data is encrypted in transit · No data shared with third parties".

### Related Play Console forms (same App content page)

| Form | Answer |
|---|---|
| Ads | **No**, the app contains no ads |
| App access | All functionality is available without special access (no login) |
| Content rating (IARC) | Utility / no violence, no user-generated content shared, no purchases; location is used but **not shared with other users** → expected rating: everyone / PEGI 3 |
| Target audience | **13+** (or 18+). Do not include under-13: that triggers the Families policy |
| News app | No |
| Health apps | No (fitness tracking of rides, not health data) — answer "My app does not have any health features" unless the console insists on the fitness category |
| Government app / financial features | No |
| Foreground service permissions | `FOREGROUND_SERVICE_LOCATION`: task "Location — user-initiated ride recording / route following", plus a short video (see below) |
| Location permissions | The app asks only for `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`, **not** `ACCESS_BACKGROUND_LOCATION` — recording with the screen off runs in a foreground service started by the user, so no background-location declaration is needed |

**Foreground service video (≤ 30 s, unlisted YouTube link):**
start a ride from Home → countdown → ride screen → show the persistent
"Recording" notification → lock the screen → unlock, distance kept growing →
Pause / Stop from the notification.

**Video:** `store/play/fgs_demo.mp4` (61 s, English captions): start a
ride, recording, persistent notification, screen off for 30 s (shortened),
distance kept growing, stop from the notification. Recorded on the emulator
with simulated GPS (`adb emu screenrecord`), cut and captioned with ffmpeg.
Upload it to YouTube as **unlisted** and paste the link into the declaration.

**Foreground service description (EN):**

> Retrail records skate and longboard rides with GPS. When the user starts a
> ride, a location foreground service with a persistent notification keeps
> recording the route while the screen is off or another app is open. The
> service runs only during a recording (or while following a saved route the
> user opened) and stops when the user pauses-and-stops or ends the ride from
> the app or the notification.

---

## Store listing

Limits: app name 30, short description 80, full description 4000 characters.
No prices, rankings, emoji or keyword lists (Play's metadata policy rejects
repeated or unrelated keywords).

Copy-ready plain-text versions (no `> ` quoting, no hard line breaks): `store/play/text/<lang>_short.txt`, `<lang>_full.txt` — regenerate them whenever the texts below change.

### Positioning and keywords

Play has no keyword field: it ranks on the **app name** (strongest), the
**short description**, then the **full description**, and each language
listing is searched on its own. A new app won't rank for "GPS tracker" against
Strava, Komoot or Runtastic, so the listing leads with the niche — **the GPS
tracker for everything on wheels** (longboard, skateboard, mountainboard,
inline skates, roller skates, scooter) — and only mentions once that it works
for any other activity (walks, hikes, bike rides). That is honest: the GPS filter
(`lib/tracking/gps_fix_filter.dart`) keeps fixes from 1.8 km/h up to
180 km/h, so walking, hiking and cycling record correctly.

Target search terms, each used once, in running text:

| English | German |
|---|---|
| skate tracker, longboard tracker, GPS tracker | Skate Tracker, Longboard, GPS-Tracker |
| track your route / record your route | Strecke aufzeichnen |
| speed, top speed, speedometer | Geschwindigkeit messen, Tacho |
| distance, km | Kilometer, Distanz |
| follow a route | Strecke / Route nachfahren |
| walk, hike, bike ride (secondary) | Spaziergang, Wanderung, Radtour (Nebenzielgruppe) |
| inline skates, rollerblading, roller skates | Inline-Skates, Inliner, Rollschuhe |

After launch, Play Console → Grow → Store listing acquisition shows the
search terms people actually used; tune the copy from that.

### Languages in Play Console

Make **English (en-US) the default language** and add German (de-DE) as a
translation (Store listing → Manage translations), each with its own texts,
screenshots (`store/play/screenshots/<lang>/`) and feature graphic. Play shows
the listing in the device language and falls back to the **default** for
every language without its own listing — with German as default, riders in
France, Spain or Brazil would see a German page.

### English (en-US, default)

**App name:** `Retrail: Skate & Longboard GPS`

**Short description:**

> GPS tracker for skate & longboard rides – track your route, speed and distance

**Full description:**

> The GPS tracker for everything on wheels. Retrail records your longboard,
> skateboard, inline skate and roller skate rides – route, speed and distance –
> and keeps them on your phone. No account, no ads.
>
> RECORD YOUR ROUTE
> • Choose your ride: longboard, skateboard, mountainboard, inline skates
>   (rollerblades), roller skates, scooter or other
> • Live map with your route, speed, distance in km, duration and top speed
> • A 10-second countdown before you roll: the last five seconds are spoken
>   and you feel a buzz, so the phone can already be in your pocket (can be
>   turned off in the settings)
> • The countdown shows whether GPS is ready
> • Pause and resume any time; keeps recording with the screen off
> • Control the ride from the notification (Android) or the Live Activity on
>   the lock screen (iPhone)
> • Recording works without cellular data
>
> FOLLOW A ROUTE AGAIN
> • Open a saved ride and follow it on the map with your live position
> • Ride it forward or backward – Retrail detects the direction
> • See how far you have to go and get a notice when you leave the route
> • Record the repeat ride, or just follow it
>
> BEAT YOUR BEST TIME
> • Recorded repeats are linked to the original ride
> • Compare every run of a route and see your best time at a glance
> • Only the time on the route counts – not the way there
> • Filter your history by followed route
>
> YOUR RIDE HISTORY
> • Every ride with a map preview, distance, time and speeds
> • Your kilometers this week, today and this year on the home screen
> • Search, filter by year, month and activity, mark favorites
> • Rename rides, add notes, navigate to a ride's start point
>
> PRIVATE BY DESIGN
> • No account, no sign-in, no ads, no tracking
> • Your rides, routes and profile stay on your device
> • The map comes from OpenFreeMap (OpenStreetMap data)
>
> Not on wheels today? Retrail also tracks any other activity – a walk, a
> hike or a bike ride.
>
> Light and dark theme. In English and German – switch the language any time
> in the settings.

### German (de-DE)

**App-Name:** `Retrail: Skate & Longboard GPS`

**Kurzbeschreibung:**

> GPS-Tracker fürs Skaten & Longboarden: Strecke, Tempo und Kilometer aufzeichnen

**Vollständige Beschreibung:**

> Der GPS-Tracker für alles, was rollt. Retrail zeichnet deine Fahrten mit
> Longboard, Skateboard, Inline-Skates und Rollschuhen auf – Strecke,
> Geschwindigkeit und Kilometer – und speichert sie auf deinem Handy. Ohne
> Konto, ohne Werbung.
>
> STRECKE AUFZEICHNEN
> • Wähle deine Aktivität: Longboard, Skateboard, Mountainboard,
>   Inline-Skates (Inliner), Rollschuhe, Roller oder Andere
> • Live-Karte mit deiner Strecke, Geschwindigkeit wie ein Tacho, Distanz,
>   Dauer und Höchstgeschwindigkeit
> • 10 Sekunden Countdown vor dem Losfahren: Die letzten fünf Sekunden
>   werden angesagt und du spürst eine Vibration – so kann das Handy schon in
>   der Tasche sein (in den Einstellungen abschaltbar)
> • Der Countdown zeigt, ob das GPS bereit ist
> • Jederzeit pausieren und weiterfahren; die Aufzeichnung läuft auch bei
>   ausgeschaltetem Bildschirm weiter
> • Steuerung über die Benachrichtigung (Android) oder die Live-Aktivität auf
>   dem Sperrbildschirm (iPhone)
> • Die Aufzeichnung funktioniert auch ohne mobile Daten
>
> STRECKEN NACHFAHREN
> • Öffne eine gespeicherte Fahrt und fahre die Route mit deiner Live-Position
>   auf der Karte nach
> • Vorwärts oder rückwärts – Retrail erkennt die Richtung
> • Sieh, wie weit es noch ist, und erhalte einen Hinweis, wenn du die Strecke
>   verlässt
> • Die Fahrt aufzeichnen oder einfach nur nachfahren
>
> SCHLAG DEINE BESTZEIT
> • Aufgezeichnete Wiederholungen werden mit der Originalfahrt verknüpft
> • Vergleiche jede Runde einer Strecke und sieh deine Bestzeit auf einen
>   Blick
> • Es zählt nur die Zeit auf der Strecke – nicht der Weg dorthin
> • Den Verlauf nach nachgefahrenen Strecken filtern
>
> DEIN FAHRTENVERLAUF
> • Jede Fahrt mit Kartenvorschau, Distanz, Zeit und Geschwindigkeiten
> • Deine Kilometer dieser Woche, von heute und des Jahres auf dem
>   Startbildschirm
> • Suchen, nach Jahr, Monat und Aktivität filtern, Favoriten markieren
> • Fahrten umbenennen, Notizen ergänzen, zum Startpunkt navigieren
>
> PRIVATSPHÄRE
> • Kein Konto, keine Anmeldung, keine Werbung, kein Tracking
> • Deine Fahrten, Strecken und dein Profil bleiben auf deinem Gerät
> • Die Karte kommt von OpenFreeMap (Daten von OpenStreetMap)
>
> Heute nicht auf Rollen unterwegs? Retrail zeichnet auch jede andere
> Aktivität auf – einen Spaziergang, eine Wanderung oder eine Radtour.
>
> Helles und dunkles Design. Auf Deutsch und Englisch – die Sprache lässt
> sich jederzeit in den Einstellungen umstellen.

### Other listing fields

| Field | Value |
|---|---|
| Category | Sports (alternative: Health & Fitness) |
| Tags | Skateboarding, GPS tracker, Sports tracking |
| Contact email | retrail.app@proton.me (same as the privacy policy; Play shows it publicly) |
| Website | https://github.com/Valijuu/Retrail (optional) |
| Privacy policy | https://valijuu.github.io/Retrail/privacy/ |

### Graphics

Made with `tool/render_store_graphics.sh` (sources and output in `store/play/`):

| Asset | File | Spec |
|---|---|---|
| App icon | `store/play/icon_512.png` | 512 × 512 PNG, 32-bit, ≤ 1 MB — from `assets/branding/app_icon.png` |
| Feature graphic | `store/play/feature_graphic_en.png`, `…_de.png` | 1024 × 500 PNG, no alpha — source `store/play/feature_graphic.html` (tagline + chips per language, two phones: light history + dark recording) |
| Phone screenshots | `store/play/screenshots/<lang>/01_track.png` … `08_activities.png` (recording, best time of a followed route, follow, history, light + dark, detail, countdown, activities) | 8 per language, 1080 × 1920, tag + caption + subline, background and enlarged excerpt per shot in `store/play/screenshots.tsv`, frame `store/play/screenshot_frame.html` (Fredoka headings, cream / peach / dark backgrounds) |

**How the screenshots are made** (no real location data anywhere):

1. `RETRAIL_DEMO_FOLLOWS=1 flutter test tool/demo_rides/build_demo_db_test.dart`
   (and again with `RETRAIL_DEMO_LANG=de`) builds
   `build/demo_rides/retrail_<lang>.sqlite`: rides on Tempelhofer Feld, Berlin
   (public park; route geometry from OpenStreetMap, ODbL, in
   `tool/demo_rides/routes.json`) with titles and comments, dates relative to
   today, including followed rides for the comparison sheet (History → the
   "Followed" chip on the top card).
2. On an Android emulator with a debug build (`run-as` needs a debuggable
   app): onboard with the name **Retrailer**, then copy the database into
   `app_flutter/retrail.sqlite` via `adb push` + `run-as … cp`. Use an AVD
   with a **1480 × 3322 px, 576 dpi** display (`Retrail_Store_2x`: same 411 dp
   layout as a 1080 px phone, twice the phone's 740 px in the frame, so the
   2x render draws it 1:1) and start it with `-gpu host` — with the default
   software renderer MapLibre drops the start/finish markers and arrows at
   that size. `wm size` on a 1080 px AVD shows the same rendering bug.
3. Live-ride shots: feed GPS with `adb emu geo fix <lng> <lat> 40 12 <knots>`
   once per second along a route — the speed argument matters, without it
   the stationary filter drops every fix.
4. Clean status bar: System UI demo mode (`sysui_demo_allowed`, clock 9:41,
   full battery and wifi, notifications hidden). Language and theme: write
   `flutter.app_language` (`en`/`de`) and `flutter.theme_mode`
   (`light`/`dark`) into `shared_prefs/FlutterSharedPreferences.xml` via
   `run-as`, with `flutter.battery_hint_dismissed` = true so the hint stays
   out of the countdown shot. The countdown shot is taken about 5.6 s after
   "Start tracking" (shows "5"); discard the ride afterwards.
5. Raw shots go to `store/play/screens/raw/<lang>_<theme>_NN_<screen>.png`;
   `tool/render_store_graphics.sh` frames them (at 2x, then halved). Raw
   shots are 1480 × 3322 (ratio 2.24), which Play rejects — always upload the
   framed ones.

## Release notes

Per release, as entered in the Play Console (≤ 500 characters per language,
line breaks included). Style: `Neu:` / `Behoben:` headings (EN `New:` /
`Fixed:`) with one `•` per change, the section with the biggest change first,
user benefit instead of internals; the closed test names fixes concretely and
ends with the plain feedback line "Feedback an / Feedback to
retrail.app@proton.me" (no thank-you for testing) — production stays
shorter and positive and never says "testing" (at most a neutral contact line
"Fragen oder Ideen? / Questions or ideas? retrail.app@proton.me"). Rules: `play-release` skill,
`references/update.md` § 5.

### 1.3.1+8 (closed test, 2026-10-21)

```
<de-DE>
Verbessert:
• Neue Reihenfolge der Aktivitäten: Longboard, Skateboard, Mountainboard, Inline-Skates, Rollschuhe, Roller, Andere – überall, wo du eine Aktivität auswählst

Feedback an retrail.app@proton.me
</de-DE>
<en-US>
Improved:
• New order of the activities: longboard, skateboard, mountainboard, inline skates, roller skates, scooter, other – everywhere you pick one

Feedback to retrail.app@proton.me
</en-US>
```

### 1.3.0+7 (closed test, 2026-10-20)

```
<de-DE>
Neu:
• Countdown-Ansage: Die letzten fünf Sekunden werden angesagt und vibrieren, beim Start kommt „Fahrt gestartet“ – so merkst du auch mit dem Handy in der Tasche, wann die Aufnahme läuft. Abschaltbar in den Einstellungen
• Der Countdown dauert jetzt 10 statt 5 Sekunden

Behoben:
• Der Countdown zeigt nach einer Fahrt mit ausgeschaltetem GPS nicht mehr fälschlich „GPS aus“

Feedback an retrail.app@proton.me
</de-DE>
<en-US>
New:
• Countdown cue: the last five seconds are spoken with a buzz each, and "Ride started" when recording begins – so you know it's running with the phone in your pocket. Can be turned off in the settings
• The countdown now runs 10 instead of 5 seconds

Fixed:
• The countdown no longer wrongly shows "GPS off" after a ride that ended with GPS switched off

Feedback to retrail.app@proton.me
</en-US>
```

### 1.2.0+6 (closed test, 2026-10-20)

```
<de-DE>
Neu:
• Fährst du eine gespeicherte Fahrt nach und zeichnest auf, wird die neue Fahrt mit dem Original verknüpft
• Vergleich im Verlauf: Original und alle Nachfahrten mit Strecke, Zeit und Tempo – die schnellste Zeit auf der Strecke bekommt einen Pokal, die Anfahrt zählt nicht mit
• Filter „Nachgefahrene Strecken“ mit Suche und Mehrfachauswahl

Entfernt:
• Der Chip „Gutes Tempo“

Feedback an retrail.app@proton.me
</de-DE>
<en-US>
New:
• Follow a saved ride while recording, and the new ride is linked to the original
• Compare in the history: the original and every repeat with distance, time and pace – the fastest time on the route gets a trophy, the way there doesn't count
• "Followed routes" filter with search and multi-select

Removed:
• The "Great pace" chip

Feedback to retrail.app@proton.me
</en-US>
```

### 1.1.2+5 (closed test, 2026-10-18)

```
<de-DE>
Behoben:
• Vor der ersten Fahrt weist die App darauf hin, wenn die Akku-Optimierung die Aufzeichnung bei ausgeschaltetem Bildschirm stoppen könnte – mit direktem Weg in die Einstellungen
• Das Menü einer Fahrt im Verlauf hat wieder die passende Farbe statt Pink

Feedback an retrail.app@proton.me
</de-DE>
<en-US>
Fixed:
• Before a ride, the app now warns you if battery optimization could stop recording with the screen off, with a direct link to the settings
• The ride menu in the history has the right color again instead of pink

Feedback to retrail.app@proton.me
</en-US>
```

### 1.1.1+4 (closed test, 2026-10-14)

```
<de-DE>
Behoben:
• Der Countdown zeigt jetzt wirklich, ob das GPS-Signal bereit ist, noch gesucht wird oder ausgeschaltet ist
• Im hellen Design sind Uhrzeit und Akku in der Statusleiste beim Fahren und im Countdown wieder gut lesbar

Danke fürs Testen! Feedback an retrail.app@proton.me
</de-DE>
<en-US>
Fixed:
• The countdown now really shows whether the GPS signal is ready, still searching or switched off
• In the light theme, the clock and battery in the status bar are readable again while riding and during the countdown

Thanks for testing! Feedback to retrail.app@proton.me
</en-US>
```

### 1.1.0+3 (closed test, 2026-10-12)

```
<de-DE>
Behoben:
• Aufzeichnung startet zuverlässig, auch wenn du das Handy während des Countdowns wegsteckst
• „Fahrt verwerfen" fragt vorher nach, damit keine Fahrt versehentlich verloren geht
• Verlauf zeigt klar, wenn ein Filter keine Treffer hat

Neu:
• Favoriten auch beim Bearbeiten einer Fahrt setzen
• Nach „Beenden" in der Benachrichtigung direkt Titel und Notiz ergänzen

Danke fürs Testen! Feedback an retrail.app@proton.me
</de-DE>
<en-US>
Fixed:
• Recording starts reliably, even if you pocket your phone during the countdown
• "Discard ride" asks first, so no ride gets lost by accident
• History tells you when a filter has no matches

New:
• Mark rides as favorite in the edit sheet
• After stopping from the notification, add a title and note right away

Thanks for testing! Feedback to retrail.app@proton.me
</en-US>
```
