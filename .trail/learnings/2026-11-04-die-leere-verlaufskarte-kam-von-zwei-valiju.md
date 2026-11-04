---
title: "Die leere Verlaufskarte kam von zwei gleichzeitigen Renders derselben Vorschau, nicht vom Timing der Screenshots"
author: Valiju
date: 2026-11-04
branch: feature/ios-screenshots
cost: { minutes: 11, tokens: 42372 }
id: l-d5195420
scope: repo
status: active
src: agent
touches:
  - lib/map/map.sdd
  - lib/map/route_preview.dart
  - lib/map/route_preview_cache.dart
  - test/map/route_preview_cache_test.dart
  - test/map/route_preview_test.dart
  - lib/features/history/history_screen.dart
---

## Decided
Gleichzeitige Anfragen für dieselbe Vorschau (Fahrt + Hell/Dunkel) teilen sich einen Render. Jede Schreibung nutzt eine eigene Temp-Datei. Eine Karte versucht einen fehlgeschlagenen Render oder ein unlesbares PNG genau einmal neu.

## Tried and ruled out
Nur atomar schreiben über eine feste ".tmp"-Datei (erster Fix zu #88): Zwei parallele Writer teilen sich die Temp-Datei, der Verlierer scheitert beim Rename oder liest ein halbes PNG. Das kaputte Bild wurde so nur zu einer dauerhaft leeren Karte.
Länger warten im Screenshot-Test: Hilft nicht, eine gescheiterte Karte erholte sich ohne Retry nie.

## Watch out
Der Verlauf fordert jede Vorschau doppelt an: das Vorladen und die Karte selbst. Die Render-Lanes werden reihum vergeben, deshalb laufen beide parallel. Der Fehler tritt zufällig auf, mal in DE, mal in EN. Der Fallback "Skizze" mit leeren Punkten ist nur eine grüne Fläche und sieht im Screenshot wie ein Ladefehler aus.

In the code: lib/map/route_preview_cache.dart (_inFlight, _tmpSeq), lib/map/route_preview.dart (_retryOnce), lib/features/history/history_screen.dart (_warmPreviews). Gesehen in Lauf 41703739305, de_light_02_history. Readiness-Härtung des Screenshot-Tests: #89.
