---
title: "Der Kartenstil ist beim Erstellen der Karte festgelegt: ein Sprachwechsel muss die native Karte neu aufbauen"
author: Valiju
date: 2026-11-18
branch: fix/map-language-rebuild
cost: { minutes: 1, tokens: 2978 }
id: l-6bc1c0a1
scope: repo
status: active
src: agent
touches:
  - lib/map/overview_map.dart
  - lib/map/live_map.dart
  - lib/map/route_preview_cache.dart
---

## Decided
Die Sprache der Ortsnamen gehört wie die Helligkeit in den Schlüssel der nativen Karte (ValueKey((dark, language))) und koppelt die alte Karte sofort ab, because MapLibre den Stil nur beim Erstellen der Karte liest; otherwise behält eine schon offene Karte ihren Stil, auch wenn die App-Sprache wechselt.

## Tried and ruled out
Die Sprache nur beim Erstellen lesen (initStyle): fails on the device only. Alle Widget- und Unit-Tests blieben grün, und frisch gestartet waren die Namen richtig; because der Verlauf-Tab beim Wechsel in die Einstellungen lebendig bleibt, zeigte die Karte nach dem Umstellen auf Englisch weiter deutsche Namen.

## Watch out
Native Kartenlogik (MapLibre) lässt sich nicht im Widget-Test prüfen, otherwise bleibt so ein Fehler unentdeckt. Alles, was Stil, Helligkeit oder Sprache der Karte ändert, am Gerät mit lebender Karte prüfen: Einstellung ändern, zurück zur Karte, Bild vergleichen (pixelgleich zum frisch gestarteten Bild der anderen Sprache).
Die Vorschaubilder im Verlauf liegen pro Sprache im Cache (ride_previews_v18_<sprache>), because ein Sprachwechsel einen neuen Cache aufbaut.
In the code: lib/map/overview_map.dart und lib/map/live_map.dart (didChangeDependencies, ValueKey), lib/map/route_preview_cache.dart.
