---
title: "Der Claude-Issue-Workflow gibt Agenten nur Leserechte, Pushen und PRs machen Jobs ohne Agent"
author: Valiju
date: 2026-11-27
branch: main
cost: { minutes: 13, tokens: 85784 }
id: l-44de9fda
scope: repo
status: active
replaces: l-de90ff93
src: agent
touches:
  - ".github/workflows/claude-issues.yml"
  - docs/claude-issues.md
  - ".github/workflows/ci.yml"
---

## Decided
claude-issues.yml läuft alle 3 Stunden, nimmt bis zu 3 der ältesten Issues mit claude (vom Owner geschrieben und gelabelt) und teilt jeden Lauf in Jobs: implement und review (Agent, nur Leserechte, liefern Patches und Texte als Artefakt) und publish, publish-fix, finish (kein Agent, schreiben). Grund: Der Agent führt Code aus (flutter test) und kann darum alles, was sein Job-Token kann; eine Liste erlaubter Befehle ist keine Sandbox. Die schreibenden Jobs prüfen die Übergabe: Autor nur claude[bot], nichts unter .github/ (ohne Rename-Lücke), keine Schließ-Schlüsselwörter für fremde Issues, Texte ohne @-Erwähnungen. main verlangt 1 Freigabe und den Check dart-check (der CI-Job hieß vorher check, wie der Job im Store-Check).
In the code: .github/workflows/claude-issues.yml, .github/workflows/ci.yml (Job dart-check), docs/claude-issues.md.

## Tried and ruled out
Ein Job mit Agent und Schreib-Token, eingeschränkt über allowedTools: Präfix-Regeln wie git push origin claude/issue-N erlaubten weitere Ziele, und Code aus flutter test hätte den Token direkt nutzen können. Den Agenten Kommentare lesen lassen: öffentliche Kommentare wären Prompt-Injection. Sofort-Start beim Label: auf Wunsch des Owners verworfen.

## Watch out
Jobs warten über die ganze Matrix aufeinander, der erste PR kann bis zu etwa 3 Stunden dauern. Artefakte sind öffentlich, darum nur eine feste Dateiliste. Nur ci.yml läuft auf claude/-Branches.
