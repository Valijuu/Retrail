---
title: "App-Store-Texte lassen sich nur ändern, wenn eine editierbare Version existiert; der Sync startet erst nach dem nächsten Build-Upload"
author: Valiju
date: 2026-11-25
branch: ci/android
id: l-0addf624
scope: repo
status: active
src: agent
touches:
  - tool/asc_sync.py
  - ".github/workflows/asc-sync.yml"
---

## Decided
Die App-Store-Texte (Beschreibung, Keywords, Promo, Was ist neu, Name, Untertitel) gehen per App-Store-Connect-API mit dem vorhandenen App-Manager-Key. Der Sync ist standardmäßig ein Trockenlauf und schreibt nur Felder, die sich unterscheiden. Er reicht nichts zur Prüfung ein und legt keine Version oder Sprache an. Das Token wird mit dem openssl-CLI signiert, damit keine pip-Pakete nötig sind.

## Tried and ruled out
Den Workflow per workflow_dispatch vom Branch starten: GitHub antwortet 404, solange die Datei nicht auf main liegt. Deshalb steht vorübergehend ein push-Trigger für ci/android drin (nur Trockenlauf), der vor dem Merge raus muss.

## Watch out
Solange die einzige iOS-Version READY_FOR_SALE ist, meldet der Sync "No editable version" und ändert nichts. Erst ein neuer Build-Upload legt die nächste Version an. Ob der Key auch schreiben darf, zeigt erst der erste Lauf mit apply.

In the code: tool/asc_sync.py, .github/workflows/asc-sync.yml, Trockenlauf-Lauf 45652954327.
