---
title: "CodeRabbit reviewt dieses Repo nur auf Kommando und hat ein knappes Gratis-Limit, der Workflow weicht sofort auf Opus aus"
author: Valiju
date: 2026-11-27
branch: chore/claude-issues-actions
cost: { minutes: 3, tokens: 46731 }
id: l-ac44fa07
scope: repo
status: active
replaces: l-8b1bb4cf
src: agent
touches:
  - docs/claude-issues.md
---

## Decided
CodeRabbit läuft hier nicht automatisch, weil das Repo unter 10 Sterne hat. Der Workflow lässt den Agenten nach dem Öffnen des PR "@coderabbitai review" kommentieren. Meldet der Bot "Review limit reached" (Gratis-Kontingent für Open Source, laut Meldung nach etwa 47 Minuten wieder frei), wechselt der Agent sofort zum Opus-Subagenten, ohne zu warten. Bei Doku und kleinen Bugfixes reichen die Tests. CodeRabbit ist kein Pflicht-Check, der Check steht bei Limit auf "skipping".
In the code: .coderabbit.yaml, Prompt in .github/workflows/claude-issues.yml, docs/claude-issues.md.

## Tried and ruled out
Auf die automatische Review der GitHub-App warten: kam nie. Die Claude-GitHub-App für PR-Ereignisse installieren: verworfen, siehe Notiz zum Workflow.

## Watch out
Ob CodeRabbit auf einen Kommentar des Actions-Bots reagiert, war beim Anlegen ungeprüft (bisher kam der Befehl von einem Nutzerkonto). Lokal scheitert gh pr edit an der Projects-classic-Meldung: gh api -X PATCH nutzen.
