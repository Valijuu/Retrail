---
title: Der Karten-Pin wird von der Karte selbst gezeichnet; das Widget darüber ist nur noch der unsichtbare Greifer
author: Valiju
date: 2026-11-11
branch: feature/history-map
id: l-3b44d7d8
scope: repo
status: active
src: agent
touches:
  - CHANGELOG.md
  - lib/features/history_map/history_map.sdd
  - lib/features/history_map/history_map_view.dart
  - lib/features/history_map/widgets/no_rides_hint.dart
  - lib/l10n/app_de.arb
  - lib/l10n/app_en.arb
  - lib/l10n/glossary_de.md
  - lib/map/overview_layers.dart
  - lib/map/overview_map.dart
  - lib/map/overview_pin.dart
---

## Decided
- Der Bereichs-Pin ist eine Symbolebene der Karte (Bild "area-pin", Material-Tropfenform per Pfad gezeichnet, Anker unten). Ein Flutter-Widget über der Karte hinkt der Kamera um einen Frame hinterher, der Pin und der Kreis zitterten beim Bewegen. Das Widget (OverviewPin) bleibt als unsichtbarer Greifer zum Ziehen; beim Ziehen zeichnet die Karte den Pin an der Fingerposition (onDragged), bis der neue Pin ankommt.
- Langer Druck setzt den Pin und bewegt die Kamera dorthin. Ein neuer Radius zoomt nur, ohne die Mitte zu ändern (nur der letzte Zoom läuft), und ein gezogener Pin bewegt die Kamera nicht. Vorher sprang der Pin beim Radius-Ändern in die Bildschirmmitte.
- Der Hinweis "Keine Fahrten mit Strecke für diese Filter" mitten auf der Karte ist wieder entfernt (#102): er stand bei jedem Umkreis ohne Fahrten dauerhaft im Bild und störte.

## Tried and ruled out
- Pin als Widget mit Schatten: Geister-Pin an der alten Position beim Verschieben, und Zittern.
- Pin aus Kreis plus Dreieck gezeichnet: sichtbare Knicke an den Schultern, wirkte nicht glatt. Die Material-Pfadkurven sind glatter.

## Watch out
- Opacity(0) fängt weiterhin Berührungen, deshalb taugt es als unsichtbarer Greifer.

In the code: lib/map/overview_pin.dart, lib/map/overview_layers.dart (area-pin), lib/map/route_marker_painter.dart (areaPinImagePng), lib/map/overview_map.dart (_fitArea, _centerOnPin).
