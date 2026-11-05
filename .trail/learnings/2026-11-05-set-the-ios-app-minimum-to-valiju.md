---
title: Set the iOS app minimum to 15.0 before the first store release
author: Valiju
date: 2026-11-05
branch: feature/ios-screenshots
cost: { minutes: 33, tokens: 151877 }
id: l-382c94d2
scope: repo
status: active
src: agent
touches:
  - docs/app-store.md
---

## Decided
The iOS app's minimum version is iOS 15.0, chosen now (before the first store release) rather than later, so no one is stuck on an old version.

In the code: ios/Runner.xcodeproj/project.pbxproj (IPHONEOS_DEPLOYMENT_TARGET 15.0 for the app; the extension stays 16.1), docs/app-store.md.

## Tried and ruled out
Keeping iOS 13.0 for the first release: Apple rejects uploads below 15.0 from April 2027 (ITMS-90068) and the warning already arrived with the first TestFlight build. Raising to 16.1 for the app: simpler, but it would also drop iOS 15 users for no reason.

## Watch out
Build 9 (uploaded before this change) still says iOS 13.0. Any new upload needs a higher build number.
