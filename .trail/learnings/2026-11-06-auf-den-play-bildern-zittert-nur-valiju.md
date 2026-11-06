---
title: "Auf den Play-Bildern zittert nur das Nachfahren-Motiv, weil die Referenzlinie aus der Demo-Datenbank stammt"
author: Valiju
date: 2026-11-06
branch: main
cost: { minutes: 19, tokens: 90954 }
id: l-bbfe3544
scope: repo
status: active
src: agent
touches:
  - store/ios/text/de_name.txt
  - store/ios/text/en_name.txt
  - docs/app-store.md
  - ios/Runner/Info.plist
  - store/ios/text/de_description.txt
  - store/ios/text/en_description.txt
  - CHANGELOG.md
  - ".github/workflows/ios-screenshots.yml"
  - store/ios/screenshots/de/01_track.png
  - store/ios/screenshots/de/02_best_time.png
---

## Decided
- Bei den Android-Store-Bildern zeigt nur 03_follow (Rohbild light_06_ride) die zittrige Linie: Es ist die hellblaue Referenzfahrt aus der Demo-Datenbank, die mit der alten Streuung von 1 m gebaut war. Die Live-Linie (selbst eingespeist) und die Detailkarte sind glatt.
- Neu aufgenommen wurde nur dieses Motiv, auf Deutsch und Englisch, mit der Datenbank mit 0,15 m Streuung. Alle anderen Bilder blieben unverändert.

## Tried and ruled out
- Alle Android-Motive neu aufnehmen: unnötig, nur das Nachfahren-Motiv zeigt die Referenzlinie bei so hoher Vergrößerung.

## Watch out
- Das Motiv ist die Fahrt "Evening skate"/"Feierabendrunde" (Nordbahn): Position an den Start setzen, Strecke nachfahren, Aufzeichnen, dann 11 s stehen und danach etwa 5,4 m/s entlang der Route einspeisen (adb emu geo fix mit Geschwindigkeit in Knoten). Bei Dauer 03:00 bis 03:05 aufnehmen.
- Der Emulator zeigt Benachrichtigungen (Zahnrad, Schild) in der Status-Leiste, die der Demo-Modus nicht ausblendet. Vor der Aufnahme "Alle löschen" in der Benachrichtigungsleiste.
- Der Demo-Modus der Status-Leiste zeigt mit "mobile show" ein "3G"-Symbol. Mobilfunk ausblenden, nur WLAN zeigen.

In the code:
- tool/demo_rides/build_demo_db_test.dart (Streuung 0,15 m)
- store/play/screens/raw/{de,en}_light_06_ride.png, tool/render_store_graphics.sh
