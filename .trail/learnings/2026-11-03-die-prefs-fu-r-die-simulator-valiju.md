---
title: "Die Prefs für die Simulator-Screenshots müssen als Datei geschrieben werden, während der Simulator aus ist"
author: Valiju
date: 2026-11-03
branch: feature/ios-screenshots
cost: { minutes: 72, tokens: 241600 }
id: l-a0f4faa5
scope: repo
status: active
replaces: l-e475f966
src: agent
touches:
  - docs/app-store.md
  - ios/Runner/PrivacyInfo.xcprivacy
  - ".github/workflows/ios-screenshots.yml"
  - tool/ios_screen_text.swift
  - tool/ios_screenshots.sh
  - tool/tool.sdd
  - store/ios/text/de_description.txt
  - store/ios/text/de_keywords.txt
  - store/ios/text/de_name.txt
  - store/ios/text/de_promo.txt
---

## Decided
Die Prefs (Name, Onboarding, Sprache, Theme) werden nach dem ersten Start als Plist-Datei in den Container der App geschrieben, while the simulator is shut down, because nothing then caches the old values. Danach bootet das Skript neu. Das Skript gibt die Datei im Log aus und prüft per Texterkennung, dass die Startseite zu sehen ist, otherwise a green run proves nothing about the picture.

## Tried and ruled out
Host-Befehl "defaults write <Pfad>": goes through the Mac's own cfprefsd, so the value sat in its cache and the file in the simulator was never written. "defaults read" returned the value, but plutil found no file. Der Simulator-Befehl "simctl spawn defaults write" brachte ebenfalls das Onboarding, vermutlich because it writes to the simulator's domain and not the app's sandbox (nicht geprüft). Ein Neustart des Simulators allein half nicht, because the file did not exist.

## Watch out
Ein grüner Lauf sagt nichts über den Bildinhalt: Größe und Status stimmten, nur der Inhalt war das Onboarding. Die PNGs ansehen. Ein Lauf dauert rund 30 Minuten, weil der Simulator pro Variante zweimal bootet.

In the code: tool/ios_screenshots.sh, tool/ios_screen_text.swift, Issue #87.
