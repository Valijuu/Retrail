---
title: App icon mark size and in-app mark
author: Valiju
date: 2026-11-07
branch: main
cost: { minutes: 34, tokens: 393834 }
id: l-2ee92764
scope: repo
status: active
src: agent
touches:
  - pubspec.yaml
  - assets/branding/app_icon_foreground.png
  - assets/branding/retrail_mark.png
  - lib/features/onboarding/init_screen.dart
---

The launcher R looked small on the Pixel because flutter_launcher_icons wraps the adaptive foreground in a 16% inset by default, so a mark that already had padding shrank twice. The foreground PNG is now sized to the 66dp safe-zone circle itself (farthest mark pixel on that circle) and pubspec sets adaptive_icon_foreground_inset: 0. The in-app mark (welcome step, feature graphic) is a separate tight-cropped assets/branding/retrail_mark.png, not the launcher foreground, so launcher geometry can change without moving the welcome step. One image serves light and dark: the white route line sits inside the orange R; what looked bad on the light surface was the extracted drop shadow and dark edge fringe, which the clean extraction removes. A dark rounded tile on the welcome step was tried and rejected by the user.
