---
title: Das Aktivitäten-Menü der Karte hat Alle/keine und kennt keine Sperre für den letzten Typ
author: Valiju
date: 2026-11-12
branch: feature/history-map
id: l-0caa33e1
scope: repo
status: active
replaces: l-59f87c74
src: agent
touches:
  - lib/features/history_map/history_map_providers.dart
  - lib/features/history_map/map_default_activity.dart
  - lib/features/history_map/map_selection.dart
  - lib/features/history_map/widgets/map_preview_card.dart
  - lib/l10n/app_de.arb
  - lib/l10n/app_en.arb
  - lib/l10n/glossary_de.md
  - lib/map/overview_map.dart
  - test/history_map/history_map_view_test.dart
---

## Decided
- Die Chip-Legende wurde ein Dropdown mit Checkboxen und einer "Alle Aktivitäten"-Zeile (Zähler am Knopf, z. B. 2/3). Die Auswahl gehört der Karte allein (siehe die Learning zur eigenen Auswahl): null ist alle, eine Menge genau diese, die leere Menge keine. Auch der letzte Typ lässt sich abwählen; "Alle" schaltet alle ein oder, wenn alle an sind, alle aus.

## Tried and ruled out
- Den letzten Typ sperren: war nur nötig, solange die Auswahl im geteilten Filter der Liste lag, wo leer "alle" bedeutet. Mit der eigenen Auswahl der Karte entfällt das, die Sperre wurde entfernt.
- Chips mit Semantics-Label als Legende: zu wenig Platz neben dem Modus-Schalter, kein sichtbarer Zustand.

In the code: lib/features/history_map/widgets/activity_menu.dart, lib/features/history_map/map_activities.dart.
