---
title: "Release bundles are built with the snap Flutter 3.44.3, not the 3.47.9 test install"
author: Valiju
date: 2026-10-31
branch: chore/release-1.3.2
cost: { minutes: 4, tokens: 6742 }
id: l-f7d744b2
scope: repo
status: active
src: agent
touches:
  - tool/build_release.sh
---

## Decided
Release bundles (1.3.2+9 onward) are built with the snap Flutter 3.44.3 that is on PATH, the same version CI pins, so the Play build matches earlier releases.

## Tried and ruled out
Building the release with the separately installed Flutter 3.47.9 (cloned to ~/sdk). It is only for checking upgrades. Its analyzer and pub get rewrite pubspec.lock and analysis_options.yaml, which must not end up in a release commit.

## Watch out
Commands: flutter format does not exist, use dart format. Before the build, check which flutter is on PATH (which flutter should show /snap/bin/flutter). tool/build_release.sh runs the build and checks the upload-key signature.
