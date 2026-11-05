---
title: "iOS store shot 03: the enlarged excerpt sits at the bottom edge, smaller"
author: Valiju
date: 2026-11-05
branch: feature/ios-screenshots
cost: { minutes: 29, tokens: 202814 }
id: l-e839509c
scope: repo
status: active
src: agent
touches:
  - store/ios/screenshots.tsv
  - store/ios/screenshot_frame.html
---

## Decided
The enlarged excerpt on iOS store shot 03 (Strecke nachfahren) is the "noch 2,43 km" bar, shown at 60 % at the bottom edge of the frame. It stays fully inside the 1320 x 2868 canvas. The raw Simulator button under it still peeks out at the right edge; that is accepted.

In the code: store/ios/screenshots.tsv (row 03_follow, pop column 0,2545,1320,200,0.6,264,2735).

## Tried and ruled out
- Bar at 80 % at the bottom edge: its lower half is cut off by the canvas edge.
- Bar moved up to the map (crop from the mid-map route, no button): hides nothing of the bottom button, and the bar then shows no motive.
- Bar at the bottom, 80 %, covering the raw button fully: the bar itself is cut off by the edge.

## Watch out
The raw shot ends at the canvas edge, so anything at its bottom is clipped. A bar that covers the raw button must also fit in the canvas, and that is not possible at 80 %. Re-check 03 in both languages after any change to the phone top (store/ios/screenshot_frame.html, currently 1000 px).
