---
title: "Das Launcher-Icon behält den dunklen Verlaufs-Tile, Weiß gilt nur für das R in der App"
author: Valiju
date: 2026-11-09
branch: main
cost: { minutes: 17, tokens: 119009 }
id: l-d5a3d282
scope: repo
status: active
src: agent
touches:
  - android/app/src/main/res/values/colors.xml
  - store/play/feature_graphic_de.png
---

## Decided
Das Launcher-Icon (Android adaptiv, iPhone, Play) zeigt das R mit Routenpin auf dem dunkelbraunen Verlauf aus dem Logo. In der App (Willkommensschritt, Feature-Grafik) steht das R ohne Tile.

## Tried and ruled out
Weißer Hintergrund (auch Cremeweiß #FFF8F5) fürs Launcher-Icon: Die weißen Pin- und Routenlinien laufen am Fuß des R ins Weiß aus, die dunklen Schattenflächen wirken schwer, der Kontrast ist schwächer. Nach dem Test auf dem Pixel 7 verworfen.

## Watch out
Alle Branding-Bilder werden von Hand nicht geändert, sie kommen aus dem Skript. Der Splash-Kreis folgt ic_launcher_background (#2B160A).

In the code: tool/build_app_icons.py (Quelle assets/branding/source/retrail_logo_tile.png), danach `dart run flutter_launcher_icons`; android/app/src/main/res/values/colors.xml.
