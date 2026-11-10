---
title: "Satellitenbilder sind vorerst nicht umgesetzt, weil keine Quelle ohne Schlüssel, Kosten und Kennzeichnung nutzbar ist"
author: Valiju
date: 2026-11-10
branch: main
cost: { minutes: 4, tokens: 77538 }
id: l-91b31d8b
scope: repo
status: active
src: agent
touches:
  - lib/map/map_attribution.dart
  - site/privacy/index.html
---

## Decided
Die Satelliten-Ansicht bleibt eine Idee auf dem Projekt-Board und ist nicht Teil der Karten-Übersicht. Kommt sie später, dann als eine globale Einstellung für alle Live-Karten; die Vorschau-Bilder bleiben Vektorkarten.

## Tried and ruled out
- Esri World Imagery über die schlüssellose Kachel-URL: laut Esri nicht frei nutzbar. Legal nur mit ArcGIS-Developer-Konto und API-Schlüssel, ohne Umsatz mit der App, unter 1 Mio. Kacheln im Monat. Der Schlüssel läge auslesbar in der App. Die Quellenangabe ist lang, und die Datenschutzerklärung bräuchte einen zweiten Kartendienst.
- MapTiler: scheidet aus, der Gratis-Plan ist nur nicht-kommerziell (#58).

## Watch out
Die Quellenhinweise stehen bewusst ausgeschrieben auf jeder Karte (Spec 19). Wer sie hinter einen Info-Knopf legen will, prüft zuerst die CC-BY-Pflicht von OpenMapTiles.

In the code: Idee auf dem Board "Satellitenansicht (global schaltbar)", `lib/map/map_attribution.dart`, `site/privacy/index.html` Abschnitt 4.
