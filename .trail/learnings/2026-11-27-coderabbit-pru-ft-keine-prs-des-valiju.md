---
title: "CodeRabbit prüft keine PRs des Actions-Bots, darum reviewt im Claude-Workflow nur Opus"
author: Valiju
date: 2026-11-27
branch: main
cost: { minutes: 42, tokens: 438625 }
id: l-2776258d
scope: repo
status: active
replaces: l-ac44fa07
src: agent
touches:
  - ".github/workflows/claude-issues.yml"
  - docs/claude-issues.md
---

## Decided
Der Claude-Issue-Workflow wartet nicht mehr auf CodeRabbit. Opus prüft jede Änderung, die nicht nur Doku ist; die Entscheidung kommt aus GitHubs Liste der geänderten Dateien, nicht aus der Einstufung des Agenten (der stufte einen 946-Zeilen-Umbau als bugfix ein). CodeRabbit bleibt für eigene PRs des Owners und die lokale CLI.
In the code: .github/workflows/claude-issues.yml (Job review), docs/claude-issues.md.

## Tried and ruled out
@coderabbitai review vom Actions-Bot: "Bot user detected", CodeRabbit verlangt dafür einen zugewiesenen Review-Platz. Derselbe Befehl vom Owner-Konto und nach einem neuen Commit (PR #158): "Review skipped", der Befehl gelte nur bei pausierten automatischen Reviews. Ein Weg über ein persönliches Token des Owners im Workflow: verworfen.

## Watch out
Der Login von CodeRabbit in der API ist coderabbitai[bot], nicht coderabbitai. Die lokale grep ist ugrep: grep -qv lieferte andere Exit-Codes als GNU grep, für Prüfungen in Skripten case-Schleifen nutzen.
