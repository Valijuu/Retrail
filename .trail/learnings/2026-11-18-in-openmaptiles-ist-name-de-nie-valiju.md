---
title: "In OpenMapTiles ist name_de nie leer: ohne deutschen Namen steht der lokale Name darin"
author: Valiju
date: 2026-11-18
branch: fix/map-nonlatin-german-names
cost: { minutes: 8, tokens: 41783 }
id: l-abd5b915
scope: repo
status: active
src: agent
touches:
  - CHANGELOG.md
  - assets/map/retrail_dark_de.json
  - assets/map/retrail_light_de.json
  - lib/map/map.sdd
  - test/map/map_styles_asset_test.dart
  - tool/build_map_styles.dart
  - tool/tool.sdd
---

## Decided
Im deutschen Kartenstil steht bei Orten mit nicht-lateinischem Namen in der ersten Zeile name_de nur dann, wenn es sich von name unterscheidet; sonst name:latin. Because OpenMapTiles das Feld name_de mit dem lokalen Namen auffüllt, wenn es keinen deutschen Namen gibt.

## Tried and ruled out
coalesce(name_de, name:latin) in der Zeile über der Originalschrift: fails on the device, because bei Orten ohne deutschen Namen die Originalschrift (Arabisch, Griechisch) doppelt erschien (zum Beispiel "ΠΕΡΙΦΕΡΕΙΑ ΚΡΗΤΗΣ" zweimal). Die Tests mit dem Stil-JSON bleiben grün, otherwise fällt das nur auf der echten Karte auf.

## Watch out
Orte ohne deutschen Namen in OpenStreetMap (zum Beispiel Kreta, West-Ennedi) bleiben englisch (name:latin): das ist richtig, keine Fehlfunktion.
Die deutschen Stile werden aus den englischen abgeleitet (tool/build_map_styles.dart); ein Test hält beide im Gleichschritt. Nach Änderungen die Karte am Gerät ansehen, nicht nur die Tests.
In the code: tool/build_map_styles.dart (_germanLatin), assets/map/retrail_*_de.json, test/map/map_styles_asset_test.dart.
