---
title: Eine Fahrt am selben Ort hat nur einen Trackpunkt und bekommt jetzt trotzdem eine Outline
author: Valiju
date: 2026-11-25
branch: fix/bug-sweep
cost: { minutes: 30, tokens: 297983 }
id: l-2f8a1885
scope: repo
status: active
src: agent
touches:
  - CHANGELOG.md
  - lib/data/db/app_database.dart
  - lib/data/db/db.sdd
  - lib/domain/ride_outline.dart
  - lib/domain/ride_outline.sdd
  - lib/features/history/history_ride_card.dart
  - lib/features/history/history_screen.dart
  - lib/features/history_map/history_map.sdd
  - lib/features/history_map/history_map_view.dart
  - lib/features/history_map/map_focus.dart
---

## Decided
Steht man beim Aufzeichnen still, speichert die Aufnahme nur den ersten Punkt (auf dem Emulator mit 14 bis 20 gleichen oder fast gleichen Fixes genau einen). Mit einem Punkt gab es früher keine Outline: die Fahrt wurde in der Aktivitätszahl ("5 Strecken") mitgezählt, aber auf der Karte nie gezeichnet und nicht gefunden (#136). Jetzt gibt ein einzelner Punkt eine Outline aus demselben Punkt zweimal, die Karte zeichnet sie als kurzes Segment (4 m) mit runden Enden, also als Punkt. Schema 9 löscht die alten leeren Markerzeilen einmal, damit solche Fahrten neu gefüllt werden.

## Tried and ruled out
Nur das Zeichnen ab zwei gleichen Punkten ergänzen: griff in der Praxis nicht, weil echte Stillstandsfahrten einen Punkt haben, nicht zwei.
Die Ein-Punkt-Regel der Domäne unangetastet lassen und nur einen Hinweis zeigen: erklärt, warum nichts zu sehen ist, macht die Fahrt aber nicht auffindbar.

## Watch out
Zum Testen der Stillstandsfahrt auf dem Emulator reicht Rauschen im Fix nicht: auch dann bleibt es ein Punkt. Die Datenbank der Debug-App lässt sich per run-as nach außen kopieren und mit sqlite lesen (trackpoints, ride_outlines).
Beim Springen aus der Liste auf die Karte ("In Karte anzeigen") kann die native Karte noch nicht bereit sein: der Fokus wartet auf das geladene Style und gilt vor dem ersten Rahmen aller Fahrten.
In the code: lib/domain/ride_outline.dart (simplify), lib/features/history_map/overview_geojson.dart (lineFragment), lib/data/db/app_database.dart (from < 9), lib/map/overview_map.dart (_pendingFocus), lib/features/history_map/map_focus.dart.
