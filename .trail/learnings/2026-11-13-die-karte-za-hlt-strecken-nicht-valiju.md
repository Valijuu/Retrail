---
title: "Die Karte zählt Strecken, nicht Fahrten: Fahrten auf derselben Linie sind eine Strecke, auch ohne Nachfahr-Verknüpfung"
author: Valiju
date: 2026-11-13
branch: feature/route-geometry-groups
cost: { minutes: 22, tokens: 425739 }
id: l-c9afed5c
scope: repo
status: active
src: agent
touches:
  - CHANGELOG.md
  - lib/features/history/history_screen.dart
  - lib/features/history_map/history_map.sdd
  - lib/features/history_map/history_map_view.dart
  - lib/features/history_map/map_items.dart
  - lib/features/history_map/widgets/activity_menu.dart
  - test/history_map/history_map_view_test.dart
  - docs/play-store.md
  - lib/features/place_search/widgets/place_search_panel.dart
---

## Decided
Fahrten, deren Linien höchstens 30 m auseinanderliegen (jeder Punkt der einen nahe an der anderen und umgekehrt), bilden eine Strecke; Nachfahr-Verknüpfungen verbinden zusätzlich, die Gruppe ist transitiv. Die Zahl im Aktivitäts-Button heißt "n von m Strecken". Eine Teilstrecke bleibt eine eigene Strecke.

## Tried and ruled out
Nur über followed_ride_id gruppieren: dieselbe Straße ohne "Nachfahren" gefahren zählte mehrfach, bei Kitzbühel "3 von 52" bei einer Linie.

## Watch out
Das Beispieldaten-Set hat 52 Follow-Gruppen auf nur 13 Linien. Die Route-Sheet (Vergleich/Bestzeit) bleibt follow-basiert; die Kartenkarte zeigt die Fahrtenzahl der Linie, das Sheet nur die verknüpften Fahrten.
In the code: lib/domain/route_match.dart, lib/features/history_map/route_lines.dart.
