---
title: "Auf dem iPhone wird ein Countdown-Clip beim Abbruch stumm geschaltet statt gestoppt, sonst bleibt die Musik leise"
author: Valiju
date: 2026-11-06
branch: feature/countdown-audio-clips
cost: { minutes: 5, tokens: 44095 }
id: l-0f465d1f
scope: repo
status: active
src: agent
touches:
  - ".specdd/bootstrap.project.md"
  - CHANGELOG.md
  - ".github/workflows/ios-build.yml"
  - README.md
  - assets/assets.sdd
  - assets/audio/countdown/README.md
  - lib/tracking/countdown_announcer.dart
  - test/tracking/countdown_announcer_test.dart
  - android/app/src/main/AndroidManifest.xml
  - assets/audio/countdown/de/1.mp3
---

## Decided
- Beim Verlassen des Countdowns stoppt iOS den laufenden Clip nicht, sondern setzt die Lautstärke auf 0 und lässt ihn zu Ende laufen. Der nächste Clip spielt wieder mit voller Lautstärke.
- Andere Audio-Apps werden nur leiser gestellt (duckOthers), nicht pausiert.

## Tried and ruled out
- Stoppen per stop(): Das iOS-Plugin gibt die Audio-Session nur frei, wenn ein Clip bis zum Ende spielt (onSoundComplete). Nach stop() oder pause() ist isPlaying false, die Freigabe wird übersprungen, die Musik bleibt dauerhaft gedämpft. Das Plugin bietet keinen Aufruf, die Session von Dart aus freizugeben.
- interruptSpokenAudioAndMixWithOthers: pausiert Podcasts, und weil das Plugin die Session ohne notifyOthersOnDeactivation freigibt, laufen sie nicht von selbst weiter.

## Watch out
- Ein Update von audioplayers_darwin kann das Verhalten ändern. Dann den Weg über stop() neu prüfen.
- Auf dem Gerät noch nicht geprüft.

In the code:
- lib/tracking/countdown_announcer.dart: stop() (iOS setVolume(0), sonst stop()), play(..., volume: 1)
- audioplayers_darwin 6.5.0: WrappedMediaPlayer.swift onSoundComplete → controlAudioSession
