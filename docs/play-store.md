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

### Positioning and keywords

Play has no keyword field: it ranks on the **app name** (strongest), the
**short description**, then the **full description**, and each language
listing is searched on its own. A new app won't rank for "GPS tracker" against
Strava, Komoot or Runtastic, so the listing leads with the niche — **the GPS
tracker for everything on wheels** (longboard, skateboard, inline skates,
roller skates, mountainboard, scooter) — and only mentions once that it works
for any other activity (walks, bike rides). That is honest: the GPS filter
(`lib/tracking/gps_fix_filter.dart`) keeps fixes from 1.8 km/h up to
180 km/h, so walking and cycling record correctly.

Target search terms, each used once, in running text:

| English | German |
|---|---|
| skate tracker, longboard tracker, GPS tracker | Skate Tracker, Longboard, GPS-Tracker |
| track your route / record your route | Strecke aufzeichnen |
| speed, top speed, speedometer | Geschwindigkeit messen, Tacho |
| distance, km | Kilometer, Distanz |
| follow a route | Strecke / Route nachfahren |
| inline skates, rollerblading, roller skates | Inline-Skates, Inliner, Rollschuhe |

After launch, Play Console → Grow → Store listing acquisition shows the
search terms people actually used; tune the copy from that.

### English (en-US, default)

**App name:** `Retrail: Skate & Longboard GPS`

**Short description:**

> GPS tracker for skate, longboard & inline rides: route, speed, km. No account.

**Full description:**

> The GPS tracker for everything on wheels. Retrail records your longboard,
> skateboard, inline skate and roller skate rides – route, speed and distance –
> and keeps them on your phone. No account, no ads.
>
> RECORD YOUR ROUTE
> • Choose your ride: longboard, skateboard, inline skates (rollerblades),
>   roller skates, mountainboard, scooter or other
> • Live map with your route, speed, distance in km, duration and top speed
> • Pause and resume any time; keeps recording with the screen off
> • Control the ride from the notification (Android) or the Live Activity on
>   the lock screen (iPhone)
> • Recording works without mobile data
>
> FOLLOW A ROUTE AGAIN
> • Open a saved ride and follow it on the map with your live position
> • Ride it forwards or backwards – Retrail detects the direction
> • See how far you have to go and get a notice when you leave the route
> • Record the repeat ride, or just follow it
>
> YOUR RIDE HISTORY
> • Every ride with a map preview, distance, time and speeds
> • Your kilometres this week, today and this year on the home screen
> • Search, filter by year, month and activity, mark favourites
> • Rename rides, add notes, navigate to a ride's start point
>
> PRIVATE BY DESIGN
> • No account, no sign-in, no ads, no tracking
> • Your rides, routes and profile stay on your device
> • The map comes from OpenFreeMap (OpenStreetMap data)
>
> Not on wheels today? Retrail also tracks any other activity, like a walk or
> a bike ride.
>
> Light and dark theme, English and German.

### German (de-DE)

**App-Name:** `Retrail: Skate & Longboard GPS`

**Kurzbeschreibung:**

> Strecke aufzeichnen beim Skaten & Longboarden: GPS-Tracker mit Tacho, ohne Konto

**Vollständige Beschreibung:**

> Der GPS-Tracker für alles, was rollt. Retrail zeichnet deine Fahrten mit
> Longboard, Skateboard, Inline-Skates und Rollschuhen auf – Strecke,
> Geschwindigkeit und Kilometer – und speichert sie auf deinem Handy. Ohne
> Konto, ohne Werbung.
>
> STRECKE AUFZEICHNEN
> • Wähle deine Aktivität: Longboard, Skateboard, Inline-Skates (Inliner),
>   Rollschuhe, Mountainboard, Roller oder Andere
> • Live-Karte mit deiner Strecke, Geschwindigkeit wie ein Tacho, Distanz,
>   Dauer und Höchstgeschwindigkeit
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
> Aktivität auf, etwa einen Spaziergang oder eine Radtour.
>
> Helles und dunkles Design, Deutsch und Englisch.

### Other listing fields

| Field | Value |
|---|---|
| Category | Sports (alternative: Health & Fitness) |
| Tags | Skateboarding, GPS tracker, Sports tracking |
| Contact email | vali_justus@live.de (same as the privacy policy; Play shows it publicly) |
| Website | https://github.com/Valijuu/Retrail (optional) |
| Privacy policy | https://valijuu.github.io/Retrail/privacy/ |

### Graphics still to make

| Asset | Spec |
|---|---|
| App icon | 512 × 512 PNG, 32-bit, ≤ 1 MB (export from `assets/branding/app_icon.png`) |
| Feature graphic | 1024 × 500 PNG/JPG, no alpha |
| Phone screenshots | 2–8, 16:9 or 9:16, each side 320–3840 px. Suggested: Home, ride screen (live map + stats), history list, ride detail, follow-route screen, dark theme. Use rides **without real home locations** (see the repo rule on real location data) |
