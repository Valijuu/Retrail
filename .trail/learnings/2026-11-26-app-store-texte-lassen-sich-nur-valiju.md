---
title: "App-Store-Texte lassen sich nur ändern, wenn eine editierbare Version existiert; der Sync startet erst nach dem nächsten Build-Upload"
author: Valiju
date: 2026-11-26
branch: ci/android
id: l-8f760a3c
scope: repo
status: active
replaces: l-0addf624
src: agent
touches:
  - tool/asc_sync.py
  - ".github/workflows/asc-sync.yml"
---

## Decided
Die App-Store-Texte (Beschreibung, Keywords, Promo, Was ist neu, Name, Untertitel) gehen per App-Store-Connect-API mit dem vorhandenen App-Manager-Key. Der Sync ist standardmäßig ein Trockenlauf und schreibt nur Felder, die sich unterscheiden. Er reicht nichts zur Prüfung ein und legt keine Version oder Sprache an. Das Token wird mit dem openssl-CLI signiert, damit keine pip-Pakete nötig sind. Der Trockenlauf zeigt auch die Screenshot-Reihenfolge im Store per MD5-Prüfsumme an; die Dateinummern im Repo folgen der Reihenfolge in den Stores.

## Tried and ruled out
Den Workflow per workflow_dispatch vom Branch starten: GitHub antwortet 404, solange die Datei nicht auf main liegt. Zum ersten Test diente ein temporärer push-Trigger für den Branch; er wurde vor dem Merge entfernt.

## Watch out
Solange die einzige iOS-Version READY_FOR_SALE ist, meldet der Sync "No editable version" und ändert nichts. Erst ein neuer Build-Upload legt die nächste Version an. Ob der Key auch schreiben darf, zeigt erst der erste Lauf mit apply.

In the code: tool/asc_sync.py, .github/workflows/asc-sync.yml, Trockenlauf-Lauf 45652954327.
