---
title: "Der Countdown spielt fertige Azure-Clips statt der Systemstimme, erzeugt im bezahlten Tarif wegen der Lizenz"
author: Valiju
date: 2026-11-06
branch: feature/countdown-audio-clips
cost: { minutes: 78, tokens: 538596 }
id: l-de06a1ec
scope: repo
status: active
src: agent
touches:
  - android/app/src/main/AndroidManifest.xml
  - assets/assets.sdd
  - assets/audio/countdown/README.md
  - assets/audio/countdown/de/1.mp3
  - assets/audio/countdown/de/2.mp3
  - assets/audio/countdown/de/3.mp3
  - assets/audio/countdown/de/4.mp3
  - assets/audio/countdown/de/5.mp3
  - assets/audio/countdown/de/go.mp3
  - assets/audio/countdown/en/1.mp3
---

## Decided
- Der Countdown (5 bis 1, "Fahrt gestartet"/"Ride started") spielt einmal erzeugte Clips ab statt flutter_tts. Grund: Die iOS-Systemstimme kam verzögert und las bei deutschen Ziffern Markup wie "homograph start … end" vor; Android und iOS klangen verschieden.
- Stimmen nach Hörvergleich durch den Nutzer: de-DE-KatjaNeural, en-GB-LibbyNeural. "Drei" etwas langsamer und tiefer (rate -5 %, pitch -4 %).
- Erzeugt über Azure AI Speech im bezahlten Tarif S0. Nur S0 gibt laut Microsoft-Produktbedingungen das Recht, die Audiodateien kommerziell zu nutzen.
- Schlusssatz bleibt "Fahrt gestartet"; Alternativen (Los geht's, Let's go, Skate-Slang, Aktivität gestartet) wurden besprochen und verworfen.

## Tried and ruled out
- Piper (offline): deutsche Frauenstimmen (Eva K, Kerstin, Ramona) gibt es nur in niedriger Qualität, Thorsten ist männlich; dem Nutzer gefiel keine.
- edge-tts: dieselben Stimmen wie Azure, aber inoffizielle Schnittstelle ohne Erlaubnis zur Weitergabe der Audiodateien. Nur für Hörproben.
- Azure-Gratistarif F0 und ElevenLabs-Gratisplan: keine kommerzielle Nutzung der Ausgabe erlaubt.
- Ziffern durch Zahlwörter ersetzen und weiter Live-TTS: hätte Verzögerung und Geräteunterschiede nicht gelöst.

## Watch out
- audioplayers verbietet in der iOS-Kategorie playback die Option allowBluetoothA2DP per Assertion. Der Fehler wurde von der best-effort-Hilfsfunktion still verschluckt, der Audio-Kontext (Ducking) wurde nie gesetzt. Nur der Test "prepare sets the ducking audio context once" hat es gezeigt.
- Microsoft verlangt den Hinweis, dass die Stimme künstlich ist (Store-Text oder Datenschutzhinweise).
- Bluetooth-Kopfhörer, gesperrter Bildschirm und Musik-Ducking sind noch nicht auf dem Gerät geprüft.

In the code:
- lib/tracking/countdown_announcer.dart (Clip-Pfad audio/countdown/<de|en>/<n|go>.mp3, AudioContext)
- assets/audio/countdown/ und README.md (Quelle, Stimmen, Region germanywestcentral, Lizenzstand 2026-11-06)
- tool/generate_countdown_clips.sh (Key aus AZURE_SPEECH_KEY oder secret-tool service retrail-azure-speech account key)
