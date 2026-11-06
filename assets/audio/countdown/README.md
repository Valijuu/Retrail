# Countdown clips

Spoken cues for the pre-ride countdown (#81): `5` to `1` and the start clip
(`go.mp3`, "Fahrt gestartet" / "Ride started").

- **Source:** Azure AI Speech, text to speech, paid tier (Standard S0), region `germanywestcentral`.
- **Voices:** `de-DE-KatjaNeural` (de), `en-GB-LibbyNeural` (en).
- **Licence:** Microsoft's Product Terms grant commercial use of audio generated with prebuilt
  neural voices on a paid TTS tier. The free tier (F0) does not carry that grant, so the clips
  must be generated on S0. Checked 2026-11-06; re-check the Product Terms when regenerating.
- **Disclosure:** the clips are synthetic voices. Microsoft asks for clear disclosure that the
  voice is synthetic; the app's store listing / privacy notes should say so.
- **Regenerate:** `tool/generate_countdown_clips.sh` (needs the key in the keychain or in
  `AZURE_SPEECH_KEY`). Do not commit a key.
