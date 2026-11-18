---
title: "specdd lint im Pipe mit tail meldet Fehler nicht als Fehlschlag, Spec-Einrückung muss genau zwei Leerzeichen sein"
author: Valiju
date: 2026-11-18
branch: fix/history-map-findings
cost: { minutes: 1, tokens: 253152 }
id: l-0c9663bb
scope: repo
status: active
src: agent
touches:
  - lib/domain/ride_outline.sdd
  - lib/domain/route_match.sdd
---

## Decided
Specs werden mit `specdd lint` ohne Pipe geprüft. Der Exit-Code entscheidet, nicht die letzte Zeile der Ausgabe. Die Hauptregel der Spec-Syntax: Körpereinträge genau zwei Leerzeichen eingerückt, Fortsetzungszeilen vier.

## Tried and ruled out
`specdd lint | tail -1 && git commit`: die Pipe liefert den Exit-Code von `tail` (0), der Commit lief mit einem Syntaxfehler in `ride_outline.sdd` durch. Erst danach aufgefallen, mit `--amend` korrigiert.

## Watch out
Ein Absatz unter einem Abschnitt, der nur drei Leerzeichen oder keinen Einzug hat, bricht den Lint, obwohl der Text inhaltlich stimmt. Vor jedem Commit mit Spec-Änderung `specdd lint` einzeln laufen lassen und `echo $?` prüfen.
In the code: lib/domain/ride_outline.sdd, lib/domain/route_match.sdd.
