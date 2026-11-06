#!/usr/bin/env bash
# Regenerates the countdown clips in assets/audio/countdown/ with Azure AI Speech (S0 tier).
# Key: AZURE_SPEECH_KEY, or the keychain entry written by:
#   secret-tool store --label="retrail azure speech" service retrail-azure-speech account key
set -euo pipefail

REGION="${AZURE_SPEECH_REGION:-germanywestcentral}"
KEY="${AZURE_SPEECH_KEY:-$(secret-tool lookup service retrail-azure-speech account key)}"
OUT="$(cd "$(dirname "$0")/.." && pwd)/assets/audio/countdown"

synth() { # voice lang file text [prosody-attrs]
  local voice="$1" lang="$2" file="$3" text="$4" attrs="${5:-}"
  local body="<prosody $attrs>$text</prosody>"
  [ -z "$attrs" ] && body="$text"
  curl -sSf -o "$file" -X POST \
    "https://$REGION.tts.speech.microsoft.com/cognitiveservices/v1" \
    -H "Ocp-Apim-Subscription-Key: $KEY" \
    -H "Content-Type: application/ssml+xml" \
    -H "X-Microsoft-OutputFormat: audio-24khz-96kbitrate-mono-mp3" \
    -H "User-Agent: retrail-tts" \
    --data "<speak version='1.0' xml:lang='$lang'><voice xml:lang='$lang' name='$voice'>$body</voice></speak>"
}

mkdir -p "$OUT/de" "$OUT/en"
synth de-DE-KatjaNeural de-DE "$OUT/de/5.mp3" "Fünf"
synth de-DE-KatjaNeural de-DE "$OUT/de/4.mp3" "Vier"
# Drei is slightly slower and lower than the default (chosen by ear, 2026-11-06).
synth de-DE-KatjaNeural de-DE "$OUT/de/3.mp3" "Drei" "rate='-5%' pitch='-4%'"
synth de-DE-KatjaNeural de-DE "$OUT/de/2.mp3" "Zwei"
synth de-DE-KatjaNeural de-DE "$OUT/de/1.mp3" "Eins"
synth de-DE-KatjaNeural de-DE "$OUT/de/go.mp3" "Fahrt gestartet"
synth en-GB-LibbyNeural en-GB "$OUT/en/5.mp3" "Five"
synth en-GB-LibbyNeural en-GB "$OUT/en/4.mp3" "Four"
synth en-GB-LibbyNeural en-GB "$OUT/en/3.mp3" "Three"
synth en-GB-LibbyNeural en-GB "$OUT/en/2.mp3" "Two"
synth en-GB-LibbyNeural en-GB "$OUT/en/1.mp3" "One"
synth en-GB-LibbyNeural en-GB "$OUT/en/go.mp3" "Ride started"
echo "Clips written to $OUT"
