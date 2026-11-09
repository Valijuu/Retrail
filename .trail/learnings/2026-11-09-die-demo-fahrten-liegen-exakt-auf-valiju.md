---
title: "Die Demo-Fahrten liegen exakt auf der Strecke, ohne GPS-Streuung"
author: Valiju
date: 2026-11-09
branch: feature/snow-activities
cost: { minutes: 106, tokens: 2441156 }
id: l-ef23fae7
scope: repo
status: active
replaces: l-fe01eaff
src: agent
touches:
  - store/ios/screenshots.tsv
  - store/play/screenshots.tsv
  - store/play/screenshots/de/01_track.png
  - store/play/screenshots/en/01_track.png
  - store/play/screens/raw/de_light_02_activities.png
  - store/play/screens/raw/de_light_04_history.png
  - store/play/screens/raw/en_light_02_activities.png
  - store/play/screens/raw/en_light_04_history.png
  - store/play/screenshots/de/02_activities.png
  - store/play/screenshots/de/03_best_time.png
---

## Decided
Die Demo-Fahrten für die Store-Bilder haben keine Streuung mehr. Auch 0,15 m ließen die Referenzlinie beim Nachfahren als Zickzack erscheinen, weil die Karte dort sehr stark vergrößert ist. Die Fixes liegen exakt auf der Routenlinie.

Die Winterfahrten nutzen echte Pisten aus OpenStreetMap (Kitzbühel). Pisten sind mit wenigen, leicht geknickten Knoten gezeichnet. Darum werden sie zusätzlich zweimal mit Chaikin-Eckenrundung geglättet, sonst sieht man Winkel.

## Tried and ruled out
- Streuung von 1 m: zittrige Linie (erste Fassung).
- Streuung von 0,15 m: war besser, auf dem Handy mit starkem Zoom aber noch sichtbar.
- Die Fleck-Piste für die Ski-Fahrt: besteht aus Serpentinen und sah im Vorschaubild wie ein Knäuel aus. Schroll-Skirast (Länge zu Luftlinie 1,17) ist klar lesbar.

## Watch out
Die Datenbank entsteht im iOS-Screenshot-Workflow; die Änderung zeigt sich erst nach einem neuen Lauf. Der Lauf hängt manchmal in simctl (zwei Läufe am 9. November, je 100 Minuten): `variants` wählt einzelne Durchgänge, jeder bricht nach 30 Minuten ab.

In the code: tool/demo_rides/build_demo_db_test.dart (_simulate, _smooth), tool/demo_rides/routes.json (schroll_piste, kaser_piste), .github/workflows/ios-screenshots.yml.
