---
title: "Auf dem Gerät taucht ein Hinweis ohne Aktion nicht im UI-Dump auf, und die leere Historie testet man durch Umbenennen der Datenbank"
author: Valiju
date: 2026-11-18
branch: chore/device-check-map
cost: { minutes: 29, tokens: 73813 }
id: l-15ed5144
scope: repo
status: active
src: agent
touches:
  - docs/android-release.md
  - tool/android_device_check.py
  - tool/tool.sdd
  - lib/features/history/area_providers.dart
  - lib/features/history_map/map_locator.dart
  - lib/features/place_search/place_search_controller.dart
  - test/history/outline_store_test.dart
  - test/place_search/place_search_controller_test.dart
  - lib/domain/ride_outline.dart
  - lib/features/history_map/history_map.sdd
---

## Decided
Geräteprüfungen per adb lesen einen Snackbar ohne Aktion aus einem Rohbild (screencap, nur im Speicher, nichts gespeichert), Vergleich gegen eine Basismessung am Bildband. Ein Snackbar mit Aktion steht dagegen im Zugänglichkeitsbaum.
Die leere Historie prüft man, indem man die Datei der Debug-App (run-as, app_flutter/retrail.sqlite) umbenennt, die App startet, und danach löscht man die neue Datei und benennt zurück. Vorher und nachher md5sum vergleichen.

## Tried and ruled out
Auf den Text des Hinweises "Der Standort ist nicht mehr verfügbar." per uiautomator dump warten: er erschien im Bild, nie im Dump, trotz mehrerer Läufe.
pm clear für die leere Historie: löscht die Testdaten, kein Weg zurück.

## Watch out
uiautomator dump braucht auf der Karte über 2 s und kann bei Animationen stumm fehlschlagen und die alte Datei liefern: vorher löschen, wiederholen.
Die Meldung bei ausgeschalteten Ortungsdiensten kommt je nach Lauf und Gerät nicht immer vom System; der Check ist deshalb best effort (SKIP statt FAIL).
Die Ortung ist ein Gerätezustand: das Skript merkt sich location_mode, wifi_on und mobile_data am Anfang und stellt sie am Ende zurück. Bricht ein Lauf ab, danach location_mode prüfen (0 = aus).
In the code: tool/android_device_check.py (band_pixels, tree), docs/android-release.md (Device check of the History map).
