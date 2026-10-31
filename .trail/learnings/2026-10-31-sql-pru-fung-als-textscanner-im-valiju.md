---
title: SQL-Prüfung als Textscanner im Pre-Commit-Hook statt custom_lint
author: Valiju
date: 2026-10-31
branch: main
cost: { minutes: 1, tokens: 1659 }
id: l-ac162291
scope: repo
status: active
src: agent
touches:
  - tool/check_raw_sql.py
  - tool/tool.sdd
  - lib/data/db/ride_dao.dart
---

## Decided
Raw-SQL-Aufrufe werden durch ein kleines Python-Skript im Pre-Commit-Hook geprüft. Es erlaubt nur feste Textliterale als SQL, otherwise könnten Eingaben per Interpolation oder Verkettung ins SQL gelangen. Werte laufen über Variable-Argumente. Die Prüfung ist bewusst einfach, because es im Repo nur zwei solcher Aufrufe gibt.

## Tried and ruled out
Ein custom_lint-Plugin mit eigener Regel: genauer, aber ein zusätzliches Paket und mehr Wartung für zwei Aufrufe, because der Aufwand den Nutzen überwiegt. Wird die Liste der Aufrufe länger, lohnt sich der Wechsel.

## Watch out
Der Hook braucht python3 im PATH, otherwise wird die Prüfung still übersprungen. Eine Ausnahme ist nur mit einem Kommentar `// sql-ok: <Grund>` auf der Aufrufzeile erlaubt. Die Prüfung ist ein Textscanner und kein vollständiger Dart-Parser, deshalb können ungewöhnliche Schreibweisen durchrutschen.

In the code:
- tool/check_raw_sql.py
- .githooks/pre-commit (Aufruf nach dem Gitleaks-Scan)
- tool/tool.sdd (Must-Eintrag)
- lib/data/db/ride_dao.dart (einziger rohes SQL-Aufruf im App-Code)
