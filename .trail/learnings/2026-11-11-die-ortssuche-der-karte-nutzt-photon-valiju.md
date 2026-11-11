---
title: "Die Ortssuche der Karte nutzt Photon, mit eigener Lupe in der Karte statt der Fahrtensuche im Kopf"
author: Valiju
date: 2026-11-11
branch: feature/place-search
id: l-cd3b66c1
scope: repo
status: active
src: agent
touches:
  - lib/features/place_search/place_search.sdd
---

## Decided
- Orte werden über Photon (photon.komoot.io, OpenStreetMap, ohne Schlüssel) gesucht: Vorschläge beim Tippen sind möglich, Anfragen erst nach 400 ms Pause und ab 3 Zeichen. Die Lupe liegt in den Kartenbedienelementen (wie bei Komoot), die Fahrtensuche im Kopf bleibt unberührt, damit sich beides nicht beißt.
- Der Suchtext geht an einen zweiten Dienst: Datenschutzerklärung in /site und Store-Antworten ändern sich im selben Zug, die Quelle steht auf dem Suchfeld.

## Tried and ruled out
- Nominatim (OSM): keine Auto-Vervollständigung, höchstens 1 Anfrage pro Sekunde. Eine Lupe mit zwei Abschnitten (Fahrten und Orte) oder eine Lupe, die mit der Ansicht wechselt: verworfen, weil jede Eingabe dann an den Ortsdienst ginge bzw. die Fahrtensuche in der Karte fehlte.

## Watch out
- Was Komoot beim Öffnen der Karte als Pin zeigt und welche Zoomstufe nach einer Suche gilt, ist nicht belegt (nur Support-Seiten gelesen, nicht in der App geprüft). Retrail startet ohne Pin und zeigt nach der Wahl den ganzen Kreis wie beim langen Druck.

In the code: lib/features/place_search/place_search.sdd (Spec, Aufgaben #106).
