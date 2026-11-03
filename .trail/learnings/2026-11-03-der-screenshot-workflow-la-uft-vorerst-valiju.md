---
title: "Der Screenshot-Workflow läuft vorerst per Push-Trigger auf dem Feature-Branch, weil er noch nicht auf main liegt"
author: Valiju
date: 2026-11-03
branch: feature/ios-screenshots
cost: { minutes: 1, tokens: 7273 }
id: l-e9e52c97
scope: repo
status: active
src: agent
touches:
  - ".github/workflows/ios-screenshots.yml"
---

## Decided
Ein neuer Workflow nur mit manuellem Start lässt sich erst auslösen, wenn er auf dem Standardbranch liegt. Deshalb steht vorübergehend ein Push-Trigger für den Feature-Branch drin. Er fliegt wieder raus, sobald der Workflow auf main ist.

## Tried and ruled out
gh workflow run auf dem Feature-Branch: liefert 404, weil die Datei nicht auf main liegt.

## Watch out
Den Push-Trigger vor dem Merge entfernen, sonst läuft der teure macOS-Job bei jedem Push.

In the code: .github/workflows/ios-screenshots.yml (Zeile mit TEMP), Issue #87.
