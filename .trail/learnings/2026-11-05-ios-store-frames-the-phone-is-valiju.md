---
title: "iOS store frames copy the Android layout; the phone top is set by the countdown button"
author: Valiju
date: 2026-11-05
branch: feature/ios-screenshots
cost: { minutes: 4, tokens: 23164 }
id: l-db5b4f1f
scope: repo
status: active
src: agent
touches:
  - store/ios/screenshot_frame.html
  - store/ios/screenshots.tsv
  - tool/demo_rides/build_demo_db_test.dart
  - tool/render_ios_store_graphics.sh
---

## Decided
The iOS store frames use the Android layout scaled to the 1320 x 2868 canvas: phone 904 px wide at left 208, bleeding off the bottom edge as on Android, pair 733 px wide. All phones share one top edge, 1040 px. 1040 is the highest value (lowest phone) at which the countdown button "Jetzt starten" (07) is still fully visible.

In the code: store/ios/screenshot_frame.html (.phone, .pair #p1, .pair #p2), store/ios/screenshots.tsv (pop positions are the Android ones scaled, minus the top shift).

## Tried and ruled out
- Phone top 1135 (straight scale of Android 760): the countdown button is cut in half.
- A separate, higher top for 07 only: the phone then sits at a different height from the rest and the user rejected it.
- Shrinking the phone to about 800 px so the whole screen fits: not the Android geometry; offered, not taken.
- An excerpt from an empty park area: it renders as a blank light box. Pick a crop with route detail.

## Watch out
The raw iOS screen is taller than the Android one, so the bottoms of 03, 04, 06 and 08 are cut by the canvas edge, as on Android. If the phone top moves below 1040, check that 07 still shows its button.
