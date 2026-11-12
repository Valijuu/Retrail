---
title: "Photon lehnt den Standard-User-Agent von Dart ab, die Ortssuche schickt den App-User-Agent der Karte mit"
author: Valiju
date: 2026-11-12
branch: feature/place-search
id: l-f4e5e7bc
scope: repo
status: active
src: agent
touches:
  - lib/features/history_map/history_map_view.dart
  - lib/features/place_search/photon_client.dart
  - lib/features/place_search/place_search.sdd
  - lib/features/place_search/widgets/place_search_panel.dart
  - test/place_search/photon_client_test.dart
  - test/place_search/place_search_controller_test.dart
---

## Decided
- Die Ortssuche sendet denselben User-Agent wie die Kartenkacheln ("Retrail (io.github.valijuu.retrail)"). Ohne ihn antwortet photon.komoot.io mit 403 und die App zeigte "nicht verfügbar", obwohl der Dienst lief. Mit curl ohne Agent klappt es, mit dem Dart-Agent nicht.
- Das Suchfeld liegt in einer nach unten begrenzten Spalte; die Treffer scrollen darin, damit die Quellenzeile über der Tastatur bleibt und die Attribution der Karte frei bleibt.

## Tried and ruled out
- Nichts weiter; der 403 war die einzige Fehlerursache am Gerät.

## Watch out
- Ein Provider, den nur `read` anfasst, wird von Riverpod 3 stillgelegt: Zustände nach einem await kommen nicht an. Tests hängen deshalb einen Zuhörer an den Provider; in der App beobachtet ihn das Suchfeld.

In the code: lib/features/place_search/photon_client.dart (kMapUserAgent), lib/features/history_map/history_map_view.dart (_searchBottomInset), test/place_search/place_search_controller_test.dart (container.listen).
