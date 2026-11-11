---
title: "Aktivitäten und Umkreis gehören der Karte allein, die Kopf-Filter gelten für Liste und Karte"
author: Valiju
date: 2026-11-11
branch: feature/history-map
id: l-ce83cd63
scope: repo
status: active
src: agent
touches:
  - lib/features/history_map/map_activities.dart
  - lib/map/overview_map.dart
---

## Decided
- Die Aktivitätsauswahl und der Pin mit Radius der Karte sind eigener Zustand der Karte, nicht Teil des Filters der Liste. Suche, Jahr, Monate, Favoriten und Strecke im Kopf bleiben geteilt, weil sie in beiden Ansichten sichtbar sind. Grund: Ein Pin oder eine Aktivität, die auf der Karte gesetzt wird, soll die Liste nicht still einschränken, und das Filter-Abzeichen soll nur die Kopf-Filter zählen.
- Die Auswahl der Karte kennt drei Zustände: null ist alle Typen, eine Menge genau diese, die leere Menge keine. Im geteilten Filter hieß leer "alle", darum war der letzte Typ gesperrt und "alles abwählen" nicht möglich; das entfällt.
- Die Karte öffnet auf der Aktivität aus den Einstellungen (nur wenn sie vorkommt und noch ein anderer Typ), einmal je Wahl; spätere Auswahl des Fahrers bleibt.
- Ein neuer Radius ändert nur den Kreis und bewegt die Kamera nicht. Nur ein per langem Druck gesetzter Pin bewegt die Kamera einmal dorthin. Mitzoomen beim Schieben wurde als zu aggressiv verworfen.

## Tried and ruled out
- Letzten Typ sperren (erste Fassung, im geteilten Filter): Der Fahrer wollte auch den letzten abwählen können.
- Alle Filter im Kopf von der Karte lösen: Dann hätten Lupe und Filter-Knopf in der Kartenansicht nichts bewirkt.

## Watch out
- Das Feature-Ziel "Karte zeigt nichts" ist jetzt gewollt möglich (0/n); die Mittelanzeige "Keine Fahrten" wurde entfernt, sie stand bei jedem leeren Umkreis dauerhaft im Bild (#102 bleibt als Idee offen).

In the code: lib/features/history_map/map_activities.dart, map_area.dart, map_default_activity.dart, lib/map/overview_map.dart (_fitArea nur bei langem Druck).
