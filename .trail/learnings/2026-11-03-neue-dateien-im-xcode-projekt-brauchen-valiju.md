---
title: "Neue Dateien im Xcode-Projekt brauchen Objekt-IDs, die es noch nicht gibt, sonst meldet Xcode das Projekt als beschädigt"
author: Valiju
date: 2026-11-03
branch: feature/ios-screenshots
cost: { minutes: 12, tokens: 17279 }
id: l-51b05863
scope: repo
status: active
src: agent
touches:
  - ios/Runner.xcodeproj/project.pbxproj
---

## Decided
Beim Ergänzen von Objekten in der Xcode-Projektdatei von Hand wird vorher geprüft, dass die ID im ganzen File nur einmal vorkommt. Das Privacy Manifest hat jetzt die IDs 200 und 201 aus dem Block 6A06…02xx.

## Tried and ruled out
Nichts anderes versucht. Der Fehler zeigte sich nur auf dem macOS-Runner, lokal gibt es keinen Mac.

## Watch out
Die Kollision (IDs 20 und 21 waren schon Release- und Profile-Konfiguration) machte den iOS-Build seit dem App-Store-Commit rot. Der Fehler lautet "XCBuildConfiguration group: unrecognized selector" und "project is damaged". Vor dem Einfügen: grep nach der ID in project.pbxproj.

In the code: ios/Runner.xcodeproj/project.pbxproj, Workflows ios-build.yml und ios-screenshots.yml.
