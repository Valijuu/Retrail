---
title: "CodeRabbit reviewt dieses Repo nur auf Kommando und hat ein knappes Gratis-Limit, die Routine weicht sofort auf Opus aus"
author: Valiju
date: 2026-11-27
branch: claude/issue-156
cost: { minutes: 14, tokens: 89275 }
id: l-8b1bb4cf
scope: repo
status: active
src: agent
touches:
  - docs/claude-routine.md
---

## Decided
CodeRabbit läuft hier nicht automatisch, weil das Repo unter 10 Sterne hat. Die Cloud-Routine schreibt nach dem Öffnen des PR selbst den Kommentar "@coderabbitai review". Meldet der Bot "Review limit reached" (Gratis-Kontingent für Open Source, nach wenigen Läufen verbraucht, Freigabe laut Meldung nach etwa 47 Minuten), wechselt die Routine sofort zum Opus-Subagenten, ohne die 10 Minuten abzuwarten. Bei reiner Doku und kleinen Bugfixes reichen die Tests. CodeRabbit ist kein Pflicht-Check: der Branch-Schutz von main verlangt keine Status-Checks, der Check steht bei Limit auf "skipping".
In the code: .coderabbit.yaml (Auto-Review dort ohne Wirkung wegen der Sterne), Prompt der Routine retrail-claude-issues, docs/claude-routine.md.

## Tried and ruled out
Auf die automatische Review der GitHub-App warten: kam nie, nur eine Meldung "fewer than 10 stars". Die Claude-GitHub-App für PR-Ereignisse installieren: verworfen, auf einem öffentlichen Repo würden fremde PR-Kommentare eine Sitzung mit Schreibrechten wecken.

## Watch out
In der Cloud scheitern gh-Befehle, die GraphQL nutzen (gh issue edit, gh pr edit): das GitHub-Werkzeug issue_write oder gh api mit REST nehmen. Lokal scheitert gh pr edit an der Projects-classic-Meldung, auch dort gh api -X PATCH nutzen. issue_write mit labels ersetzt alle Labels, nicht nur ein einzelnes.
