---
title: "Das Launcher-R füllt 87 Prozent des sicheren Bereichs, aufs Handy per adb install -r"
author: Valiju
date: 2026-11-09
branch: main
cost: { minutes: 6, tokens: 8914 }
id: l-7d042346
scope: repo
status: active
src: agent
---

## Decided
Das R im adaptiven Launcher-Icon nutzt 87 % des Radius der 66-dp-Sicherheitszone, im iPhone- und Play-Icon ist es 56 % der Höhe. 100 % klebte am Rand, 82 % war dem Nutzer zu klein.

## Watch out
`flutter install` hat das Pixel einmal deinstalliert und neu installiert (App-Daten weg). Zum Testen `adb install -r build/app/outputs/flutter-apk/app-release.apk` nutzen.

In the code: FG_FILL und ICON_FILL in tool/build_app_icons.py, danach `python3 tool/build_app_icons.py` und `dart run flutter_launcher_icons`.
