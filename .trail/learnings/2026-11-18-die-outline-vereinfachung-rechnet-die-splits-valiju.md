---
title: "Die Outline-Vereinfachung rechnet die Splits einmal, bleibt im schlechtesten Fall aber quadratisch"
author: Valiju
date: 2026-11-18
branch: fix/history-map-findings
cost: { minutes: 50, tokens: 557263 }
id: l-77dbbef1
scope: repo
status: active
src: agent
touches:
  - lib/features/history_map/history_map.sdd
  - lib/map/overview_pin.dart
  - lib/data/db/db.sdd
  - lib/data/db/outline_dao.dart
  - lib/data/repositories/outline_repository.dart
  - lib/features/history_map/outline_fill.dart
  - test/history_map/outline_fill_test.dart
  - lib/features/place_search/place_search.sdd
  - lib/features/place_search/place_search_controller.dart
  - test/history_map/map_selection_test.dart
---

## Decided
Die Vereinfachung einer Fahrt läuft einmal bei 5 m mit einem eigenen Stapel statt Rekursion und merkt sich pro Punkt seine Wichtigkeit (kleinster Abstand entlang der Teilungskette). Die verdoppelte Toleranz filtert nur noch. Das Ergebnis ist identisch mit dem alten Verfahren, das ein Test gegen eine Kopie des alten Algorithmus prüft.
Outline-Zeilen tragen seit Schema 8 eine Revision, die jedes Umschreiben erhöht. Der Cache lädt eine Fahrt neu, wenn sich ihre Revision ändert, ohne alle Zeilen neu zu lesen.

## Tried and ruled out
Nur die Rekursion durch einen Stapel ersetzen: behebt den Stack-Überlauf, aber nicht die Neustarts je Toleranzstufe.
Einen Test mit 200000 Punkten für den Stack-Überlauf: braucht über zwei Minuten, weil der erste Durchlauf bei jeder Teilung am Anfang trotzdem quadratisch ist. 20000 Punkte brauchen schon rund 45 s. Der Test zählt deshalb Distanzaufrufe bei 500 und 1000 Punkten.

## Watch out
#99 ist nur zum Teil behoben: Neustarts und Rekursionstiefe sind weg, der Einzeldurchlauf bleibt im schlechtesten Fall O(n²). Echte Fahrten (Zufallsweg) sind schnell. Wer sehr lange, zackige Tracks speichert, braucht ein anderes Verfahren (Rang einmal berechnen, zum Beispiel Visvalingam).
In Dart-Tests überlaufen schon rund 10000 verschachtelte Aufrufe den Stack, nicht erst Hunderttausende.
In the code: lib/domain/ride_outline.dart (_splitImportance), lib/data/db/outline_dao.dart (watchOutlineRevisions), lib/features/history/area_providers.dart (OutlineStore.refresh).
