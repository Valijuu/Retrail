---
title: Ein Datenbank-Stream im Füll-Controller der Karte läuft in jedem History-Tab und lässt die Shell-Tests hängen
author: Valiju
date: 2026-11-18
branch: fix/history-map-findings
cost: { minutes: 26, tokens: 875329 }
id: l-9a8e80c0
scope: repo
status: active
src: agent
touches:
  - lib/features/history_map/history_map.sdd
  - lib/features/history_map/map_selection.dart
  - test/history_map/map_selection_test.dart
  - lib/features/history_map/outline_fill.dart
  - test/home/home_test_helpers.dart
---

## Decided
Der Füll-Controller der Karte beobachtet den Stream "gibt es Fahrten ohne Outline" nur, solange die Füllung gewollt ist (Karte sichtbar oder Bereich gesetzt, App im Vordergrund). Ein bedingtes ref.watch im build reicht, weil build bei jeder Änderung dieser Werte neu läuft.

## Tried and ruled out
Den Stream immer beobachten: Der History-Screen beobachtet den Füll-Controller dauerhaft, also lief die Drift-Abfrage hinter jeder Liste. In Tests blieb beim Abbau ein offener Drift-Timer ("Pending timers", StreamQueryStore.markAsClosed); die Shell-Tests hingen, der volle Lauf brauchte über 30 Minuten statt rund 80 Sekunden.

## Watch out
Jeder neue Drift-watch-Stream, der vom History-Screen aus erreichbar ist, braucht entweder eine Bedingung oder einen Stub in den gemeinsamen Test-Stubs (homeStreamStubs). Ein hängender Gesamtlauf mit "Pending timers" deutet zuerst auf so einen Stream.
Tests für die Karten-Auswahl, die von der Linien-Zuordnung abhängen, müssen auf die berechneten Linien warten, nicht auf eine feste Pause.
In the code: lib/features/history_map/outline_fill.dart (OutlineFillController.build), test/home/home_test_helpers.dart (homeStreamStubs), test/history_map/map_selection_test.dart (linesKeyed).
