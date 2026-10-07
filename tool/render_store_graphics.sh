#!/usr/bin/env bash
# Renders the Google Play listing graphics into store/play/:
#   icon_512.png              512 x 512 app icon (from assets/branding/app_icon.png)
#   feature_graphic_<l>.png   1024 x 500 feature graphic per language (no alpha)
#   screenshots/<l>/NN_*.png  1080 x 1920 phone screenshots per language, framed
#                             with a caption (store/play/screenshots.tsv) from
#                             the raw emulator shots in store/play/screens/raw/
# Needs google-chrome (headless) and python3 with Pillow. The feature graphic
# loads Roboto from Google Fonts, so it needs network access.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/store/play"

python3 - "$root" <<'PY'
import sys
from PIL import Image
root = sys.argv[1]
icon = Image.open(f"{root}/assets/branding/app_icon.png").convert("RGBA")
icon.resize((512, 512), Image.LANCZOS).save(f"{root}/store/play/icon_512.png", optimize=True)
PY

for lang in en de; do
  png="$out/feature_graphic_$lang.png"
  google-chrome --headless=new --disable-gpu --hide-scrollbars \
    --window-size=1024,500 --virtual-time-budget=5000 \
    --screenshot="$png" "file://$out/feature_graphic.html?lang=$lang" 2>/dev/null
  python3 -c "from PIL import Image; import sys; Image.open(sys.argv[1]).convert('RGB').save(sys.argv[1], optimize=True)" "$png"
done

urlencode() { python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$1"; }
for lang in en de; do
  mkdir -p "$out/screenshots/$lang"
  while IFS=$'\t' read -r name raw theme en de; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    title="$en"; [[ "$lang" == de ]] && title="$de"
    png="$out/screenshots/$lang/$name.png"
    url="file://$out/screenshot_frame.html?theme=$theme&img=$(urlencode "screens/raw/${lang}_$raw.png")&title=$(urlencode "$title")"
    google-chrome --headless=new --disable-gpu --hide-scrollbars \
      --window-size=1080,1920 --virtual-time-budget=5000 \
      --screenshot="$png" "$url" 2>/dev/null
    python3 -c "from PIL import Image; import sys; Image.open(sys.argv[1]).convert('RGB').save(sys.argv[1], optimize=True)" "$png"
  done < "$out/screenshots.tsv"
done
ls -l "$out"/*.png "$out"/screenshots/*/*.png
