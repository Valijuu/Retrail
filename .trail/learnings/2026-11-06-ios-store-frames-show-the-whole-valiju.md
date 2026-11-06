---
title: iOS store frames show the whole phone with bottom padding
author: Valiju
date: 2026-11-06
branch: fix/ios-store-frames
cost: { minutes: 22, tokens: 82960 }
id: l-8cc86b43
scope: repo
status: active
replaces: l-db5b4f1f
src: agent
touches:
  - store/ios/screenshot_frame.html
  - store/ios/screenshots.tsv
  - tool/render_ios_store_graphics.sh
---

## Decided
The iOS store frames no longer copy the Android bleed-off layout. The user asked for the whole phone, clear space under it and a bottom that looks like a real iPhone. In store/ios/screenshot_frame.html the copy starts at 124 px, .phone is 830 px wide at left 245, top 760, border-radius 106 (about the display corner radius of the device). The phone ends about 295 px above the canvas edge. The pair (light + dark) starts at 760 px with its higher right phone (#p2), #p1 179 px lower.

## Bottom of the phone
The bottom 102 raw px (34 pt) of every Simulator shot are the home indicator area. On the ride (light_07_track) and follow (light_05_follow) screens it is near-black (#1C1B1F) under the light action bar. fit() in tool/render_ios_store_graphics.sh fills such a uniform band with the bar colour above it and draws the home indicator pill on every shot (the screenshot leaves it out).

## Tried and ruled out
- Cropping the bottom 102 raw px off every shot: removes the black strip, but the action bar and tab bar then sit in the rounded corners and the bottom does not look like a real device.

## Excerpts
Pop positions in screenshots.tsv are canvas px and must move with the phone; after a size change scale the pop centres about (660, phone top). The German detail dialog sits 30 raw px lower than the English one, so screenshots.tsv has an optional 12th column (German pop), used only for 06_detail.

## Watch out
The excerpt outline is 90 % white, so text right under it shows faintly. History (top 1468) and detail (EN 1740, DE 1769) are placed so no row of the phone behind is cut in half.
