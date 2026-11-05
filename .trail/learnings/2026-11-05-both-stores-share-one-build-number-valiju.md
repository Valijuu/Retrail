---
title: Both stores share one build number
author: Valiju
date: 2026-11-05
branch: feature/ios-screenshots
cost: { minutes: 2, tokens: 8457 }
id: l-3966ad26
scope: repo
status: active
src: agent
touches:
  - pubspec.yaml
---

## Decided
Both stores share one build number, counted up on every upload to any store. The version name (1.3.2) changes only when users see something new.

In the code: pubspec.yaml (version: 1.3.2+10), one source for Android versionCode and iOS CFBundleVersion.

## Tried and ruled out
Separate build numbers per platform via --build-number in the workflows: every store gets a gap-free list, but two numbers must be kept in step by hand at each release.

## Watch out
An upload to only one store leaves a gap in the other. That is harmless: the stores only require a rising number per app.
