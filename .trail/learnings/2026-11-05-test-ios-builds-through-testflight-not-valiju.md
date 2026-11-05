---
title: "Test iOS builds through TestFlight, not Splice sideloading"
author: Valiju
date: 2026-11-05
branch: feature/ios-screenshots
cost: { minutes: 3, tokens: 12597 }
id: l-46427c62
scope: repo
status: active
src: agent
touches:
  - tool/ios_fetch_build.sh
---

## Decided
With the paid Apple Developer account, test builds go to the iPhone through TestFlight, not through Splice sideloading. The release workflow uploads the signed build; the iPhone needs no USB cable.

In the code: .github/workflows/ios-release.yml (upload=true), tool/ios_fetch_build.sh (unsigned sideload path, kept as fallback).

## Tried and ruled out
Splice sideloading with the paid account: it fails with DeveloperPortalError 8210 ("Your team has no current certificates") even after a fresh splice login. Re-logging in did not help, so the team's development certificate state is the cause, not the login.

## Watch out
Internal testers must be added under TestFlight, and the Apple ID on the iPhone must be a team member. An invitation code screen means the device is not an internal tester yet. A new build shows only after Apple has finished processing (minutes to about 30).
