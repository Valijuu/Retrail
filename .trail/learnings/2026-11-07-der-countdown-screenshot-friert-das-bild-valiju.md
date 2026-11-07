---
title: "Der Countdown-Screenshot friert das Bild ein, bis der Host es aufgenommen hat"
author: Valiju
date: 2026-11-07
branch: main
cost: { minutes: 22, tokens: 162158 }
id: l-fd8b3050
scope: repo
status: active
replaces: l-76a36ebc
src: agent
touches:
  - docs/play-store.md
  - integration_test/store_screenshots_test.dart
  - tool/ios_screenshots.sh
  - store/ios/screenshots_6_3/en/07_countdown.png
---

## Decided
Der Host nimmt das Bild 1 bis 15 s nach dem Marker auf (Lauf 42366838171: Leseschleife mit sed, simctl get_app_container und neuem simctl io pro Shot; unter Kartenlast am langsamsten). Der Countdown läuft dabei in Echtzeit weiter, und während der 320-ms-Rolle zeigt das Bild zwei Ziffern. Deshalb stellt der Test für diesen Shot das Binding auf die Frame-Policy onlyPumps und pumpt beim Warten auf das Ack nicht: der Bildschirm behält den letzten sauberen Frame, egal wie lange der Host braucht. Danach zurück auf fullyLive.

## Tried and ruled out
Ein Zeitfenster nach "+5 sec." (Tap, 340 ms warten, Shot): setzte voraus, dass der Host in unter 660 ms aufnimmt. Er brauchte 1,2 bis 1,7 s, EN zeigte wieder zwei Ziffern, DE war nur zufällig sauber. Den Ticker in der App anhalten: der Timer liegt privat im State, das bräuchte einen Zugang nur für Tests im Produktcode.

## Watch out
Beim eingefrorenen Shot darf das Warten auf das Ack kein tester.pump aufrufen, jeder Pump zeichnet einen Frame. Dass ein ausgelassener Frame im iOS-Simulator stehen bleibt, ist aus dem Binding-Code abgeleitet; der erste Lauf damit (nach Commit mit diesem Learning) bestätigt oder widerlegt es. Ein grüner Lauf sagt nichts über den Bildinhalt, das Bild ansehen.

In the code: integration_test/store_screenshots_test.dart (_shot mit freeze, Testfall 06_countdown, 07_track), tool/ios_screenshots.sh (Leseschleife ab Zeile 217).
