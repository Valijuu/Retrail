---
title: "Das Ende einer Fahrt wird mit ihren Statistiken in einer Transaktion geschrieben, Tests warten vor dem Schließen"
author: Valiju
date: 2026-11-26
branch: feature/ride-end-transaction
cost: { minutes: 1, tokens: 3268 }
id: l-08fa3d9d
scope: repo
status: active
src: agent
touches:
  - lib/data/db/ride_dao.dart
  - lib/data/repositories/ride_repository.dart
  - test/data/ride_repository_test.dart
  - test/tracking/ride_recording_controller_test.dart
---

## Decided
Endzeit und Statistik einer Fahrt stehen jetzt in einer einzigen Datenbank-Transaktion, weil ein Beobachter sonst eine beendete Fahrt ohne Statistik sieht und eine Unterbrechung dazwischen sie so zurücklässt. Die Transaktion liegt am DAO (`inTransaction`), das Berechnen der Statistik bleibt im Repository.

## Tried and ruled out
Beide Schreibvorgänge nacheinander lassen: eine Unterbrechung dazwischen hinterließ eine beendete Fahrt mit leeren Statistikfeldern, und der Verlauf zeigte kurz diesen Zwischenzustand.

## Watch out
Der Tracker schreibt das Ende ohne Warten (unawaited). Seit der Transaktion dauert das länger, deshalb meldeten fünf Aufnahme-Tests einen Fehler "nach dem Ende des Tests", weil die Datenbank vorher schloss. Das Teardown der Aufnahme-Tests wartet nun 50 ms auf offene Schreibvorgänge.
Den Test für die Atomarität schreibt man über die Zustände, die ein Beobachter sieht (Stream der Fahrt), weil sich ein Fehler mitten im Schreiben nicht künstlich einbauen lässt.
In the code: lib/data/db/ride_dao.dart (inTransaction), lib/data/repositories/ride_repository.dart (updateEndTime), test/data/ride_repository_test.dart, test/tracking/ride_recording_controller_test.dart (tearDown).
