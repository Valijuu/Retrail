---
title: Auf der Karte gibt es eine Vorschaukarte pro Strecke; die Fahrten einer Strecke öffnen über den Zähler
author: Valiju
date: 2026-11-11
branch: feature/history-map
id: l-eb4d1c48
scope: repo
status: active
src: agent
touches:
  - lib/features/history_map/map_selection.dart
  - lib/features/history_map/route_badges.dart
  - lib/features/history_map/widgets/map_preview_card.dart
---

## Decided
- Tippt man auf eine Linie, zeigt die Karte einen Eintrag pro Strecke (Gruppe aus Original und Nachfahrten): die beste Fahrt der Gruppe mit Pokal, dazu der Zähler "n Fahrten auf dieser Strecke". Der Zähler öffnet die vorhandene Streckenliste. Das Wischen mit n/m bleibt nur für verschiedene Strecken unter dem Finger. Grund: Alle Fahrten einer Strecke zeichnen dieselbe Linie, das Wischen zeigte immer dasselbe Bild.

## Tried and ruled out
- Kompakte Liste in der Karte: macht die Karte hoch und verdeckt mehr Karte.
- Nur die neueste Fahrt ohne Wischen: die Vergleichsansicht der Strecke ginge verloren.

## Watch out
- Pro Gruppe gilt die beste Fahrt, wenn sie getroffen wurde, sonst der nächste Treffer. Der Gruppenschlüssel ist die ID des Originals (RouteBadges.groupKeyOf).

In the code: lib/features/history_map/map_selection.dart (selectedRidesProvider), lib/features/history_map/route_badges.dart, lib/features/history_map/widgets/map_preview_card.dart.
