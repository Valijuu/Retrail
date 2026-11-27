---
title: "Claude bearbeitet Issues mit Label claude alle 3 Stunden per GitHub Actions, bis zu 3 nacheinander, und sieht nur Text des Owners"
author: Valiju
date: 2026-11-27
branch: chore/claude-issues-actions
cost: { minutes: 13, tokens: 283379 }
id: l-de90ff93
scope: repo
status: active
replaces: l-f9ef46b9
src: agent
touches:
  - ".github/workflows/claude-issues.yml"
  - docs/claude-issues.md
---

## Decided
Der Workflow claude-issues.yml läuft nur nach Zeitplan (alle 3 Stunden) und auf Knopfdruck, nicht beim Setzen des Labels. Er nimmt bis zu 3 der ältesten offenen Issues mit claude, die der Owner geschrieben und gelabelt hat, setzt claude-laeuft und arbeitet sie nacheinander ab (Matrix, max-parallel 1). Der Agent bekommt den Issue-Text und nur Kommentare des Owners als Datei, kein gh issue view, gh pr view, gh api oder Web. Das Warten auf CodeRabbit macht ein Shell-Schritt ohne Agent; Befunde gehen als Datei an einen zweiten Agent-Schritt, bei Limit prüft ein Opus-Schritt Features. main verlangt seitdem 1 Freigabe und einen grünen check, damit der Job-Token nicht mergen kann; der Owner behält den Admin-Bypass.
Grund für den Wechsel weg von der Cloud-Routine: Sie pushte mit dem Admin-Konto des Owners und hatte weder Flutter noch specdd.
In the code: .github/workflows/claude-issues.yml, docs/claude-issues.md; Labels claude-laeuft, claude-fehler; Cloud-Routine retrail-claude-issues pausiert.

## Tried and ruled out
Sofort-Start beim Label (issues: labeled): verworfen auf Wunsch des Owners, außerdem verdrängten fremde Label-Events wartende Läufe in der concurrency-Gruppe. Den Agenten Kommentare selbst lesen lassen: öffentliche Kommentare von Dritten wären Prompt-Injection mit Zugriff auf Claude-Token und Job-Token, weil der Agent Code ausführen kann (flutter test) und die Bash-Befehle die ganze Job-Umgebung erben. CODEOWNERS erzwingen: Admin umgeht es ohnehin.

## Watch out
Die erlaubte Shell-Liste ist keine Sandbox. Ein PR, den der Job-Token öffnet, startet die CI nicht selbst: der Job ci dispatcht ci.yml; Android-, iOS- und Store-Workflows laufen für claude/-Branches nicht. Die Reihenfolge der Matrix-Jobs ist in der Praxis die Listenreihenfolge, aber von GitHub nicht zugesichert. Die Läufe zählen gegen das Abo-Limit.
