---
title: "Der Countdown-Screenshot wird kurz nach einem Neustart des Sekundentakts aufgenommen, weil der Host die Aufnahme verzögert"
author: Valiju
date: 2026-11-07
branch: main
cost: { minutes: 1, tokens: 18197 }
id: l-76a36ebc
scope: repo
status: active
src: agent
touches:
  - integration_test/store_screenshots_test.dart
---

## Decided
Der EN-Countdown-Screenshot zeigte eine "3" über einer halben "2": der Host nimmt das Bild mit unbekannter Verzögerung auf, der Countdown läuft weiter, und bei jedem Ziffernwechsel rollt die Ziffer 320 ms lang. Der Test tippt deshalb nach 4,2 s auf "+5 sec.", das startet den Sekundentakt neu, und fordert die Aufnahme erst 340 ms später an. Bis zum nächsten Wechsel bleiben rund 660 ms. Die Ziffer im Bild ist dadurch zweistellig (um die 10).

## Tried and ruled out
Das Timing der Aufnahme im Test zu verschieben ohne den Takt anzuhalten: die Verzögerung des Hosts ist zufällig, ein fester Zeitpunkt trifft den Wechsel irgendwann wieder. Den Timer von außen anhalten geht nicht, er liegt privat im State des Bildschirms; ein Test-Hook in der App wurde für ein Store-Bild nicht eingebaut.

## Watch out
Wird die Aufnahme am Simulator langsamer als etwa 660 ms, kann der Fehler wiederkommen. Ein grüner Lauf sagt nichts über den Bildinhalt, das Bild immer ansehen. Ersatzbilder erst hochladen, wenn die laufende App-Store-Prüfung durch ist.

In the code: integration_test/store_screenshots_test.dart (Testfall 06_countdown, 07_track), Commit 97e6d04, Lauf 42366838171.
