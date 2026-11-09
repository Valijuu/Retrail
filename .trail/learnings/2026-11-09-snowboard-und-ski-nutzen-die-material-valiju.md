---
title: "Snowboard und Ski nutzen die Material-Symbole mit Fahrer, selbst gezeichnete Bretter wurden verworfen"
author: Valiju
date: 2026-11-09
branch: feature/snow-activities
cost: { minutes: 1, tokens: 10226 }
id: l-c689f1e9
scope: repo
status: active
src: agent
touches:
  - store/store.sdd
  - assets/icons/activity/snowboard.svg
  - lib/domain/activity_type.dart
---

## Decided
Die Icons für Snowboard und Ski sind die Material-Symbole "snowboarding" und "downhill_skiing". Das Skateboard-Icon kommt aus derselben Familie (Figur auf dem Brett), so passen Strichstärke und Stil zusammen. Ski ist ein einziger Typ für alpin, Tour und Langlauf; Liftfahrten werden vorerst mit aufgezeichnet.

## Tried and ruled out
- Eigene Glyphen ohne Figur: Das Snowboard wirkte wie ein Pflaster, die zwei Ski wie ein Kreuz (Schließen-Symbol) oder dünne Stöcke. Auch nach mehreren Überarbeitungen nicht überzeugend.
- Schlittschuhe als weiterer Typ: Weder Rollen noch Brett, passt nicht zur Positionierung "Rollen und Brett". Wasser (Surfen, SUP), E-Board und Langlauf als eigener Typ sind Ideen für später.

## Watch out
Store-Texte dürfen Snow-Wörter erst nennen, wenn die Typen in einer ausgelieferten Version stecken (store/store.sdd). Die Lizenz der Material-Symbole ist Apache 2.0, wie beim Skateboard-Icon.

In the code: assets/icons/activity/snowboard.svg und ski.svg; lib/domain/activity_type.dart; Issue #94.
