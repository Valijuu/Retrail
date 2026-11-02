---
title: "iOS-Screenshots kommen aus dem Simulator auf dem macOS-Runner, die Motive per Integrationstest und Marker"
author: Valiju
date: 2026-11-02
branch: feature/ios-screenshots
cost: { minutes: 21, tokens: 189769 }
id: l-da164da6
scope: repo
status: active
src: agent
touches:
  - docs/app-store.md
  - store/play/screenshots/en/08_activities.png
  - store/play/screenshots/en/03_follow.png
  - store/play/screenshots/en/02_best_time.png
---

## Decided
Es gibt keinen Mac, deshalb entstehen die App-Store-Screenshots im iOS-Simulator auf dem GitHub-macOS-Runner. Die weiteren Motive soll ein Integrationstest ansteuern, der Marker auf stdout ausgibt; das Shell-Skript macht beim Marker den Screenshot mit simctl.

## Tried and ruled out
Die Android-Screenshots (1080 x 1920, Android-Oberfläche) wiederverwenden: Apple verlangt 1320 x 2868 für 6.9 Zoll. Screenshots per takeScreenshot im Test: erfasst vermutlich die MapLibre-Karte (Plattform-View) nicht, nicht geprüft.

## Watch out
Der Workflow ist noch nie gelaufen, mehrere Annahmen sind ungeprüft (Liste in Issue #87). Der Sperrbildschirm mit Live Activity ist nicht automatisiert.

In the code: tool/ios_screenshots.sh, .github/workflows/ios-screenshots.yml, docs/app-store.md, Issue #87.
