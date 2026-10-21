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

# The feature graphic renders at 2x and is scaled down with Lanczos: its
# phones show the raw shots at 18 %, which blurs at scale 1.
shrink() { python3 -c "from PIL import Image; import sys; Image.open(sys.argv[1]).convert('RGB').resize((int(sys.argv[2]), int(sys.argv[3])), Image.LANCZOS).save(sys.argv[1], optimize=True)" "$@"; }

for lang in en de; do
  png="$out/feature_graphic_$lang.png"
  google-chrome --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=2 \
    --window-size=1024,500 --virtual-time-budget=5000 \
    --screenshot="$png" "file://$out/feature_graphic.html?lang=$lang" 2>/dev/null
  shrink "$png" 1024 500
done

# Screenshots: each raw shot is scaled once with Lanczos to its exact size in
# the frame (phone 740 px wide, 600 px in a light + dark pair) and drawn 1:1
# at scale 1 — letting Chrome scale the 1080 px raw shot blurs it. A light
# unsharp mask brings back the edge contrast the 68 % downscale takes away.
prep="$root/build/store_frames"
mkdir -p "$prep"
fit() { python3 -c "
import sys
from PIL import Image, ImageFilter
im = Image.open(sys.argv[1]).convert('RGB')
w = int(sys.argv[3])
im = im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)
im.filter(ImageFilter.UnsharpMask(radius=0.8, percent=70, threshold=2)).save(sys.argv[2])" "$@"; }
excerpt() { python3 -c "
import sys
from PIL import Image
x, y, w, h, s = map(float, sys.argv[3].split(',')[:5])
im = Image.open(sys.argv[1]).convert('RGB').crop((int(x), int(y), int(x + w), int(y + h)))
im.resize((round(w * s), round(h * s)), Image.LANCZOS).save(sys.argv[2])" "$@"; }

urlencode() { python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$1"; }
for lang in en de; do
  mkdir -p "$out/screenshots/$lang"
  rm -f "$out/screenshots/$lang"/*.png
  while IFS=$'\t' read -r name raw raw2 bg pop en_tag en_title en_sub de_tag de_title de_sub; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    tag="$en_tag" title="$en_title" sub="$en_sub"
    [[ "$lang" == de ]] && { tag="$de_tag" title="$de_title" sub="$de_sub"; }
    png="$out/screenshots/$lang/$name.png"
    width=740; [[ "$raw2" != - ]] && width=600
    fit "$out/screens/raw/${lang}_$raw.png" "$prep/${lang}_$name.png" "$width"
    url="file://$out/screenshot_frame.html?bg=$bg&img=$(urlencode "$prep/${lang}_$name.png")"
    url+="&tag=$(urlencode "$tag")&title=$(urlencode "$title")&sub=$(urlencode "$sub")"
    if [[ "$raw2" != - ]]; then
      fit "$out/screens/raw/${lang}_$raw2.png" "$prep/${lang}_${name}_2.png" "$width"
      url+="&img2=$(urlencode "$prep/${lang}_${name}_2.png")"
    fi
    if [[ "$pop" != - ]]; then
      excerpt "$out/screens/raw/${lang}_$raw.png" "$prep/${lang}_${name}_pop.png" "$pop"
      url+="&pop=$pop&popimg=$(urlencode "$prep/${lang}_${name}_pop.png")"
    fi
    google-chrome --headless=new --disable-gpu --hide-scrollbars \
      --window-size=1080,1920 --virtual-time-budget=5000 \
      --screenshot="$png" "$url" 2>/dev/null
    python3 -c "from PIL import Image; import sys; Image.open(sys.argv[1]).convert('RGB').save(sys.argv[1], optimize=True)" "$png"
  done < "$out/screenshots.tsv"
done
ls -l "$out"/*.png "$out"/screenshots/*/*.png
