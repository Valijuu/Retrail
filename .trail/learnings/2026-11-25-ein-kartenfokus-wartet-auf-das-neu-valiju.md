---
title: Ein Kartenfokus wartet auf das neu geladene Verzeichnis und verfällt nicht bei einer Kamerabewegung
author: Valiju
date: 2026-11-25
branch: main
cost: { minutes: 9, tokens: 417988 }
id: l-20f9a6a3
scope: repo
status: active
src: agent
touches:
  - lib/features/history_map/map_focus.dart
  - lib/map/overview_map.dart
  - test/tracking/ride_recording_controller_test.dart
  - CHANGELOG.md
  - lib/data/db/app_database.dart
  - lib/data/db/db.sdd
  - lib/domain/ride_outline.dart
  - lib/domain/ride_outline.sdd
  - lib/features/history/history_ride_card.dart
  - lib/features/history/history_screen.dart
---

## Decided
"In Karte anzeigen" wartet auf die frisch geladene Übersicht, bevor die Fahrt als nicht auf der Karte gilt. Die Frist (2,5 s) verlängert sich, solange die Übersicht noch lädt oder ihre Linien noch gefüllt werden. Ein Fokus, der während des Ladens des Karten-Styles ankommt, wird beim Laden angewendet. Eine Kamerabewegung des Fahrers danach verwirft ihn, sonst springt die Karte zu einer älteren Fahrt zurück. Der Anfangszustand kommt auch über das Erzeugen des Widgets an, nicht nur über Änderungen.

## Tried and ruled out
Die Frist einfach ablaufen lassen: nach einem Filter-Reset lädt die Übersicht neu, und die Fahrt kam nach 2,5 s zu spät, obwohl sie da war. Als Befund hat der Review das gefunden, nicht der Test.
Den Fokus nur über `didUpdateWidget` setzen: beim Erzeugen des Widgets kommt er nie an. Im Ablauf war das nicht erreichbar, bleibt aber als Absicherung.

## Watch out
Review-Befunde mit Frage im Text prüfen: Zwei von drei großen Befunden waren Fehlalarme (Startfehler, Datenbank-Retry), die Fix-Änderung war trotzdem sinnvoll, wo ein Befund berechtigt war.
Der Test für den Startfehler muss nach dem erfolgreichen Retry die Warteschlange leeren, sonst schreibt die Datenbank nach dem Schließen.
In the code: lib/features/history_map/map_focus.dart (_expire, advance), lib/map/overview_map.dart (_pendingFocus, _onStyleLoaded, initState), test/tracking/ride_recording_controller_test.dart.
