---
title: "Claude bearbeitet Issues mit Label claude per GitHub Actions statt Cloud-Routine, mit Token ohne Admin-Rechte"
author: Valiju
date: 2026-11-27
branch: chore/claude-issues-actions
cost: { minutes: 3, tokens: 46731 }
id: l-f9ef46b9
scope: repo
status: active
replaces: l-99d97b36
src: agent
touches:
  - docs/claude-issues.md
---

## Decided
Der Workflow claude-issues.yml startet beim Setzen des Labels claude (und alle 3 Stunden) und bearbeitet das älteste offene Issue mit Label, ohne claude-pr und claude-rueckfrage. Grund für den Wechsel weg von der Cloud-Routine: Die Cloud-Sitzung pushte mit dem Admin-Konto des Owners (PR-Autor war Valijuu), also umging sie den Branch-Schutz von main, und sie hatte weder Flutter noch specdd. Der Actions-Token ist kein Admin, hängt am Branch-Schutz und kann keine Workflow-Dateien ändern. Die Workflow-Datei kommt bei Issue- und Schedule-Ereignissen immer aus main. Das Claude-Token liegt im Environment claude, das nur main annimmt. Sicherheitsprüfung: Sender des Labels, Autor und Label-Setzer müssen der Owner sein. Review: erst CodeRabbit (Kommando im PR), bei Limit sofort Opus-Subagent bei Features.
In the code: .github/workflows/claude-issues.yml, docs/claude-issues.md; Cloud-Routine retrail-claude-issues ist pausiert (enabled false), nicht gelöscht.

## Tried and ruled out
Cloud-Routine weiter nutzen: kein Flutter, Admin-Rechte. Claude-GitHub-App installieren: fremde PR-Kommentare könnten eine Sitzung wecken. CODEOWNERS erzwingen: der Admin kann es ohnehin umgehen, bringt kaum Schutz.

## Watch out
Ein PR, den der Job-Token öffnet, startet die CI nicht von selbst: der Job ci dispatcht ci.yml auf dem Branch (workflow_dispatch ist erlaubt). Die 13 alten Repo-Secrets liegen weiter als Repo-Secrets, nicht in Environments. Die Läufe zählen gegen das Abo-Limit.
