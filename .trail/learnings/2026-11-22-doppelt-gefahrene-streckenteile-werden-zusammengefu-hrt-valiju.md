---
title: "Doppelt gefahrene Streckenteile werden zusammengeführt, aber in Fahrtreihenfolge und mit 1 mm Toleranz"
author: Valiju
date: 2026-11-22
branch: main
cost: { minutes: 102, tokens: 442484 }
id: l-08070dc2
scope: repo
status: active
src: agent
touches:
  - lib/domain/area_filter.dart
  - lib/domain/distance_calculator.dart
  - lib/domain/domain.sdd
  - lib/domain/follow_progress.dart
  - lib/domain/geo_constants.dart
  - lib/domain/geo_constants.sdd
  - lib/domain/heading.dart
  - lib/domain/outline_hit.dart
  - lib/domain/ride_outline.dart
  - lib/domain/route_progress.dart
---

## Decided
Überlappende oder sich berührende gefahrene Teile einer Strecke werden zu einem Teil zusammengeführt, damit ein doppelt gefahrenes Stück nur einmal gezeichnet wird (sonst wirkt es durch die Deckkraft dunkler). Der zusammengeführte Teil bleibt an der Stelle des ersten aufgenommenen Teils, die Fahrtreihenfolge bleibt erhalten. Berührend heißt: Abstand höchstens 1e-6 m.
Um zu belegen, dass die 17 fehlschlagenden Szenarien der vollen Follow-Suite nicht neu sind, läuft dieselbe Suite auf main in einem Worktree und die Namen der Fehlschläge werden verglichen. Auf main und auf dem Branch scheitern dieselben 17.
Der Pfad eines Profilfotos wird relativ zum Documents-Ordner gespeichert und beim Lesen wieder absolut gemacht. Ein früher gespeicherter absoluter Pfad wird beim Lesen auf den aktuellen Ordner umgestellt (ab dem Teil "profile_photos/"), deshalb braucht es keine Migration. Eine unlesbare Fotodatei zeigt den leeren Avatar.
Das Android-Cloud-Backup schließt den ganzen Documents-Ordner aus (Datenbank, Vorschauen, Fotos); Einstellungen bleiben im Backup. Direkter Telefon-Transfer ab Android 12 trägt weiter alles.

## Tried and ruled out
Nach Start sortieren und dann zusammenführen: bricht die Tests, die für Strecken über die Start/Ziel-Linie die Fahrtreihenfolge (zuerst 340–400, dann 0–60) festlegen.
Exakte Gleichheit als "berührend": Eine volle Runde zerfiel nach einer Konstanten-Umstellung in zwei Teile, weil die Grenzen um etwa 1e-13 m auseinanderlagen.
Vergleich ohne die Datei: Im Worktree fehlt die gitignorierte test/fixtures/real_rides.json, dort laufen weniger Fälle (279 statt 427), die Zahlen sind nicht vergleichbar.
Fehler in der Anzeige suchen: Die Datei war da, nur der gespeicherte absolute Pfad zeigte in einen alten Container. Android ist nicht betroffen, sein Pfad bleibt über Updates gleich.
Einzelne Unterordner vom Backup ausnehmen: Die Vorschau-Ordner heißen nach Version und Sprache, Backup-Regeln kennen keine Platzhalter.

## Watch out
Auf offenen Strecken rückwärts kommen die Teile nicht in Karten-Reihenfolge heraus (die Liste wird nur umgedreht, nicht sortiert). Für das Zeichnen ist das egal; Tests dürfen die Reihenfolge dort nicht festschreiben.

In the code: riddenIntervals und _merged in lib/domain/follow_lap.dart; Tests in test/domain/follow_tracker_test.dart und test/follow/route_follow_providers_test.dart (#57).
Vor dem Lauf die Datei in den Worktree kopieren. Der Lauf selbst dauert gut eine Minute pro Seite.

In the code: flutter test test/domain/follow_tracker_scenarios_test.dart --dart-define=FOLLOW_SCENARIOS_ALL=true --reporter expanded, Fehlschläge mit grep "\[E\]" vergleichen.
Wer neue Dateipfade in den Einstellungen oder der Datenbank ablegt, darf keine absoluten Pfade speichern. Der Review fand auch: git stash ist in dieser Umgebung per Hook gesperrt, für einen Rot-Grün-Vergleich die Datei aus HEAD zurückkopieren.

In the code: ProfilePhotoPaths und PreferencesRepository(photoRoot:), Backup-Regeln in android/app/src/main/res/xml/ (#134).
