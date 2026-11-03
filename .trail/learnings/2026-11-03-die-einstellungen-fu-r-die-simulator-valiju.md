---
title: "Die Einstellungen für die Simulator-Screenshots müssen direkt in den App-Container, nicht über den Simulator-Befehl"
author: Valiju
date: 2026-11-03
branch: feature/ios-screenshots
cost: { minutes: 1, tokens: 2032 }
id: l-e475f966
scope: repo
status: active
src: agent
touches:
  - tool/ios_screenshots.sh
---

## Decided
Die Prefs (Name, Onboarding, Sprache, Theme) gehen direkt in die Preferences-Datei des App-Containers, because the app only reads them from there. Das Skript prüft den Wert danach und bricht sonst ab, otherwise a silent miss goes unnoticed again.

## Tried and ruled out
Schreiben über den Simulator-Befehl für Defaults: Der Lauf war grün, but the shots showed onboarding in English without demo rides, because that command writes to the simulator's own domain.

## Watch out
Ein grüner Lauf sagt nichts über den Bildinhalt: Die Größe stimmte (1320 x 2868), only the content was wrong, so look at the PNGs. Der Fix ist bis zum nächsten Lauf unbestätigt. Ein Push startet den Lauf neu und bricht den laufenden ab, because the concurrency group sets cancel-in-progress.

In the code: tool/ios_screenshots.sh, Issue #87.
