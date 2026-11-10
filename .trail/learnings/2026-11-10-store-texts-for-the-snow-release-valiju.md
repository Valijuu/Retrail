---
title: "Store texts for the snow release wait in a draft folder, not in the live text files"
author: Valiju
date: 2026-11-10
branch: feature/snow-activities
cost: { minutes: 2, tokens: 21101 }
id: l-c1955500
scope: repo
status: active
src: agent
touches:
  - store/draft-1.4.0/README.md
  - store/draft-1.4.0/ios/de_description.txt
  - store/draft-1.4.0/ios/de_keywords.txt
  - store/draft-1.4.0/ios/de_name.txt
  - store/draft-1.4.0/ios/de_promo.txt
  - store/draft-1.4.0/ios/de_subtitle.txt
  - store/draft-1.4.0/ios/de_whatsnew.txt
  - store/draft-1.4.0/ios/en_description.txt
  - store/draft-1.4.0/ios/en_keywords.txt
  - store/draft-1.4.0/ios/en_name.txt
---

## Decided
The 1.4.0 store texts (Skate & Snow name, slogan, snow words) are prepared in a separate draft folder and copied over only when the snow types ship.

## Tried and ruled out
Editing the live text files now: the store spec allows snow words only once an app version with the types is released, and the live files are what gets uploaded.

## Watch out
Delete the draft folder at release time. The German iOS keywords were 102 characters at first; the limit is 100.

In the code: store/draft-1.4.0/ (README explains the copy step), store/store.sdd.
