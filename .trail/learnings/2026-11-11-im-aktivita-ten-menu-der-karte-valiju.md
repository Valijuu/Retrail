---
title: "Im Aktivitäten-Menü der Karte bleibt der letzte Typ immer an, weil der leere Filter alle zeigt"
author: Valiju
date: 2026-11-11
branch: feature/history-map
id: l-59f87c74
scope: repo
status: active
src: agent
touches:
  - CHANGELOG.md
  - lib/features/history_map/history_map.sdd
  - lib/features/history_map/history_map_view.dart
  - lib/features/history_map/legend_toggle.dart
  - lib/features/history_map/outline_fill.dart
  - lib/features/shell/main_shell.dart
  - lib/features/shell/shell.sdd
  - lib/l10n/app_de.arb
  - lib/l10n/app_en.arb
---

## Decided
- Die Legende aus Chips wurde durch ein Dropdown mit Checkboxen ersetzt (ein Button mit Zähler wie 2/3). Der letzte angehakte Typ ist gesperrt: Im geteilten Verlauf-Filter bedeutet die leere Auswahl "alle Typen", darum sprang beim Abwählen des letzten Typs alles wieder an. Die Sperre ist für den Nutzer verständlicher als ein leerer Kartenzustand und hält die Bedeutung des Filters unverändert.

## Tried and ruled out
- Chips mit Semantics-Label als Legende: Zu wenig Platz neben dem Modus-Schalter, schlecht antippbar, kein Zustand sichtbar. Vom Nutzer verworfen.
- Abwählen des letzten Typs als "alle zeigen" (alter Stand): wirkt wie ein Fehler.

## Watch out
- Der graue Punkt in der Kartenmitte ohne Fahrten war ein Objekt der Basiskarte bei 0/0, kein Positionsmarker: Die Startansicht ohne Daten liegt darum über Europa.
- Ortungsdienste am Testgerät sind oft aus; die Karte meldet das als Snackbar, das ist kein Fehler.

In the code: lib/features/history_map/legend_toggle.dart (legendTypeLocked, toggleLegendType), lib/features/history_map/widgets/activity_menu.dart, lib/map/overview_map.dart (_fallbackLat/_fallbackLon).
