---
title: Claude bearbeitet Issues mit Label claude per Cloud-Routine alle 3 Stunden und öffnet nur PRs
author: Valiju
date: 2026-11-27
branch: chore/coderabbit-config
cost: { minutes: 21, tokens: 94332 }
id: l-99d97b36
scope: repo
status: active
src: agent
touches:
  - ".coderabbit.yaml"
---

## Decided
Eine Cloud-Routine (Name retrail-claude-issues, alle 3 Stunden) nimmt das älteste offene Issue mit Label claude und öffnet einen PR gegen main. Das Label ist die Sperre: nur der Owner kann Labels setzen, die Routine prüft zusätzlich Autor und Label-Setzer per Issue-Events. Sonnet arbeitet, große Issues gibt er an einen Opus-Subagenten ab. Bei Features reviewt ein Opus-Subagent, weil CodeRabbit in der Cloud nicht angemeldet ist; CodeRabbit reviewt danach den PR über die GitHub-App. main hat Branch-Schutz (PR nötig, kein Force-Push, kein Löschen), der Admin ist ausgenommen.
In the code: .coderabbit.yaml; Labels claude, claude-pr, claude-rueckfrage; Routine https://claude.ai/code/routines/trig_01GvT8uC8J7fUptQuekXWpAE.

## Tried and ruled out
Einzelne Issues privat machen: geht bei GitHub nicht, Issues sind so sichtbar wie das Repo. Privates Aufgaben-Repo: verworfen, das Label mit Autor-Prüfung reicht. Branch-Schutz auch für Admins (enforce_admins): verworfen, sonst bricht finish_branch.sh, das main direkt per Rebase pusht.

## Watch out
Draft-Items auf dem Board haben keine Labels; nur Issues lösen die Routine aus. Ob die Cloud-Umgebung Flutter und specdd hat, war beim Anlegen ungeprüft. Der erste PR (#154) ist der erste Test, ob die CodeRabbit-App auf PRs reagiert.
