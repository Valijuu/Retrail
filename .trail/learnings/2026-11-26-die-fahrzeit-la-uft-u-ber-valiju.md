---
title: Die Fahrzeit läuft über die Uhr statt über gezählte Timer-Ticks
author: Valiju
date: 2026-11-26
branch: fix/elapsed-from-timestamps
cost: { minutes: 1, tokens: 1932 }
id: l-47fbda74
scope: repo
status: active
src: agent
touches:
  - lib/tracking/ride_tracker.dart
  - test/tracking/ride_tracker_test.dart
---

## Decided
Die live angezeigte Fahrzeit ist die Summe der abgeschlossenen Abschnitte plus der laufende Abschnitt, gelesen über `clock.now()`, because ein im Hintergrund gedrosselter Timer weniger Ticks liefert und die Anzeige sonst langsamer lief als die gespeicherte Dauer aus den Zeitstempeln. Pause und Stopp schließen den laufenden Abschnitt ab, deshalb zählt eine Pause nicht mit.

## Tried and ruled out
`DateTime.now()` direkt: fails with virtueller Zeit, because fakeAsync diese Uhr nicht bewegt und alle Tracker-Tests brechen würden. `package:clock` bewegt fakeAsync mit, deshalb braucht es keine eigene injizierbare Uhr.

## Watch out
Einen gedrosselten Timer simuliert man im Test mit `fa.elapseBlocking(...)`, because die Uhr dann springt, ohne dass ein Timer feuert. Mit `fa.elapse` allein bleibt ein Tick-Zähler unentdeckt, otherwise kommt dort jeder Tick an.
In the code: lib/tracking/ride_tracker.dart (_elapsedBeforeMs, _runStartedMs, _bankElapsed, _resetElapsed), test/tracking/ride_tracker_test.dart (group elapsed).
