---
title: "Der Karten-Pin bekommt keinen Icon-Schatten, sonst bleibt beim Verschieben ein dunkler Geister-Pin stehen"
author: Valiju
date: 2026-11-11
branch: feature/history-map
id: l-01a3ec33
scope: repo
status: active
src: agent
touches:
  - CHANGELOG.md
  - lib/features/history_map/history_map.sdd
  - lib/features/history_map/history_map_view.dart
  - lib/features/history_map/legend_toggle.dart
  - lib/features/history_map/widgets/activity_menu.dart
  - lib/features/history_map/widgets/map_controls.dart
  - lib/features/history_map/widgets/map_preview_card.dart
  - lib/l10n/app_de.arb
  - lib/l10n/app_en.arb
  - lib/l10n/glossary_de.md
---

## Decided
- Der Bereichs-Pin (OverviewPin, Marker im WidgetLayer) wird ohne Schatten am Icon gezeichnet. Mit "shadows" am Icon blieb beim Verschieben der Karte (Finger im Suchkreis) eine dunkle Kopie des Pins an der alten Bildschirmposition stehen, während der orange Pin korrekt mitwanderte. Am Pixel 7 reproduziert und nach dem Entfernen des Schattens verschwunden.

## Tried and ruled out
- SegmentedButton-Höhe per minimumSize/maximumSize erzwingen: wirkt bei compact-Dichte nicht. Stattdessen Standarddichte (40 dp) für beide Bedienelemente der Kartenzeile.

## Watch out
- Nicht wieder Schatten an Marker-Icons des WidgetLayers hängen; der Fehler zeigt sich nur im Gerät, nicht im Widget-Test.

In the code: lib/map/overview_pin.dart, lib/features/history_map/widgets/map_controls.dart (kMapControlHeight).
