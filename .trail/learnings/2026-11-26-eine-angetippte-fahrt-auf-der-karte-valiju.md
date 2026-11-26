---
title: Eine angetippte Fahrt auf der Karte wird nicht durch die schnellste Fahrt derselben Strecke ersetzt
author: Valiju
date: 2026-11-26
branch: feature/map-own-location
cost: { minutes: 19, tokens: 948979 }
id: l-b59e3c41
scope: repo
status: active
src: agent
touches:
  - lib/features/history/history_screen.dart
  - lib/features/history_map/history_map_view.dart
  - lib/features/history_map/map_focus.dart
  - lib/features/history_map/map_selection.dart
  - lib/features/profile/profile_photo_manager.dart
  - lib/map/overview_map.dart
  - lib/tracking/ride_recording_controller.dart
  - test/data/ride_outlines_dao_test.dart
  - test/history_map/map_selection_test.dart
  - CHANGELOG.md
---

## Decided
Die Karte zeigt zu einer Strecke die schnellste Fahrt (Bestzeit). Für "In Karte anzeigen" und den Tipp auf den eigenen Standort gilt das nicht: die gewünschte Fahrt bleibt, auch wenn eine andere Fahrt derselben Strecke die Bestzeit hat. Die Auswahl trägt dafür ein Kennzeichen "exakt", das beim Tippen auf die Karte zurückgesetzt wird.

## Tried and ruled out
Die Auswahl nur über die Fahrt-ID setzen: die Karte ersetzte sie beim Zeichnen durch die Bestzeit, der Fahrer sah eine andere Fahrt als die gewünschte.
Den Standard-Aktivitätsfilter nach dem Fokus laufen lassen: konnte die angeforderte Fahrt wieder ausblenden. Jetzt wartet er, solange ein Fokus aussteht.

## Watch out
Fahrten derselben Strecke haben nur bei gleicher Strecken-ID dieselbe Karte. Ein Test braucht zwei Fahrten, eine mit Nachfahr-Verknüpfung und die schnellere als Bestzeit.
Ein Fokus, der während des Styleladens kommt, gilt nur bis zur nächsten Kamerabewegung des Fahrers. Die Zählung dafür steht beim Anfordern, nicht beim Anwenden.
In the code: lib/features/history_map/map_selection.dart (MapSelection.exact, selectedRideProvider), lib/features/history_map/history_map_view.dart (_applyDefaultActivity), lib/map/overview_map.dart (_pendingFocusMoves).
