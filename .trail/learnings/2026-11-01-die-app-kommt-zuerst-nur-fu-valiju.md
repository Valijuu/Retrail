---
title: "Die App kommt zuerst nur für iPhone in den App Store, ohne iPad"
author: Valiju
date: 2026-11-01
branch: feature/app-store-prep
cost: { minutes: 3, tokens: 76616 }
id: l-2ad8b424
scope: repo
status: active
src: agent
touches:
  - docs/app-store.md
  - ios/Runner.xcodeproj/project.pbxproj
  - ios/Runner/Info.plist
  - ios/Runner/PrivacyInfo.xcprivacy
  - ios/ios.sdd
---

## Decided
iOS-Release startet nur für iPhone. Das Layout ist auf Hochformat am Handy ausgelegt, und iPad-Screenshots und iPad-Tests entfallen. Ohne bezahltes Apple-Developer-Konto (Stand 2026-11-01) bleibt Sideloading der einzige iOS-Weg; Signing und Upload laufen später über GitHub Actions, weil es keinen Mac gibt.

## Tried and ruled out
iPhone und iPad zusammen: hätte iPad-Screenshots und einen iPad-Test verlangt, ohne dass das Layout dafür gebaut ist.

## Watch out
Ohne bezahltes Konto ist kein App-Store-Upload möglich, die kostenlose Apple ID signiert nur 7 Tage.

In the code: ios/Runner.xcodeproj/project.pbxproj (TARGETED_DEVICE_FAMILY = 1), ios/Runner/Info.plist, Plan in docs/app-store.md.
