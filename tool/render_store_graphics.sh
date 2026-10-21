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

# Everything renders at 2x and is scaled down with Lanczos: drawn at scale 1,
# text and the scaled raw shots come out blurry.
shrink() { python3 -c "from PIL import Image; import sys; Image.open(sys.argv[1]).convert('RGB').resize((int(sys.argv[2]), int(sys.argv[3])), Image.LANCZOS).save(sys.argv[1], optimize=True)" "$@"; }

for lang in en de; do
  png="$out/feature_graphic_$lang.png"
  google-chrome --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=2 \
    --window-size=1024,500 --virtual-time-budget=5000 \
    --screenshot="$png" "file://$out/feature_graphic.html?lang=$lang" 2>/dev/null
  shrink "$png" 1024 500
done

# Screenshots render at 2x like the feature graphic and are halved with
# Lanczos. The raw shots are taken at 1480 px wide (twice the 740 px phone),
# so the phone draws them 1:1; only the light + dark pair (600 px) and the
# enlarged excerpts are scaled, once, with Lanczos. Excerpt boxes in
# screenshots.tsv are in 1080 px units and scale with the raw shot.
prep="$root/build/store_frames"
mkdir -p "$prep"
fit() { python3 -c "
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert('RGB')
w = int(sys.argv[3])
if im.width != w: im = im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)
im.save(sys.argv[2])" "$@"; }
excerpt() { python3 -c "
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert('RGB')
k = im.width / 1080
x, y, w, h, s = map(float, sys.argv[3].split(',')[:5])
im = im.crop((round(x * k), round(y * k), round((x + w) * k), round((y + h) * k)))
im.resize((round(w * s * 2), round(h * s * 2)), Image.LANCZOS).save(sys.argv[2])" "$@"; }

urlencode() { python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$1"; }
for lang in en de; do
  mkdir -p "$out/screenshots/$lang"
  rm -f "$out/screenshots/$lang"/*.png
  while IFS=$'\t' read -r name raw raw2 bg pop en_tag en_title en_sub de_tag de_title de_sub; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    tag="$en_tag" title="$en_title" sub="$en_sub"
    [[ "$lang" == de ]] && { tag="$de_tag" title="$de_title" sub="$de_sub"; }
    png="$out/screenshots/$lang/$name.png"
    width=1480; [[ "$raw2" != - ]] && width=1200
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
    google-chrome --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=2 \
      --window-size=1080,1920 --virtual-time-budget=5000 \
      --screenshot="$png" "$url" 2>/dev/null
    shrink "$png" 1080 1920
  done < "$out/screenshots.tsv"
done
ls -l "$out"/*.png "$out"/screenshots/*/*.png
