---
title: Ein Migrationsschritt liest nur die Spalten seiner eigenen Version
author: Valiju
date: 2026-11-26
branch: fix/migration-chain
cost: { minutes: 6, tokens: 26688 }
id: l-8b1a39be
scope: repo
status: active
src: agent
touches:
  - lib/data/db/app_database.dart
  - lib/data/db/db.sdd
  - test/data/migration_chain_test.dart
  - lib/tracking/ride_tracker.dart
  - test/tracking/ride_tracker_test.dart
  - CHANGELOG.md
  - lib/tracking/tracking.sdd
  - pubspec.lock
  - pubspec.yaml
---

## Decided
Ein Datenbank-Upgrade-Schritt liest und schreibt mit festem SQL nur die Spalten, die es bei seiner Version gibt, because die DAOs immer die heutigen Spalten selektieren und eine alte Datei diese im Upgrade noch nicht hat. Das v1/v2→v3-Backfill fiel genau daran mit "no such column: rides.followed_ride_id".

## Tried and ruled out
Die Schritte unter v3 einfach streichen: verworfen, because eine v1/v2-Datei dann ohne Statistikspalten weiterliefe; kein Store-Nutzer hat eine, aber die Kette soll ganz bleiben.
Drift-Schema-Snapshots (make-migrations): nicht eingeführt, because Kettentests ab rohen v1- und v3-Schemas dasselbe Risiko mit weniger Werkzeug abdecken.

## Watch out
Die Punkte im Backfill nach trackpoint_id sortieren, nicht nach Zeit, otherwise kann die Strecke bei ungeordneten oder gleichen Zeitstempeln von der bisherigen Berechnung (Einfügereihenfolge) abweichen.
`m.addColumn`/`m.createTable` mit den heutigen Tabellen sind sicher, because sie nur die eine Spalte oder Tabelle anlegen.
In the code: lib/data/db/app_database.dart (_backfillStatsAndRoute), test/data/migration_chain_test.dart, lib/data/db/db.sdd.
