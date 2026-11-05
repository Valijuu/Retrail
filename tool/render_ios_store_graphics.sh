#!/usr/bin/env bash
# Frames the App Store screenshots (1320 x 2868, 6.9" iPhone) into
# store/ios/screenshots/<lang>/NN_*.png: caption, subline and the raw Simulator
# shot in a phone outline (store/ios/screenshot_frame.html). The raw shots come
# from tool/ios_screenshots.sh (the iOS screenshots workflow artifact), by
# default from build/ios_screenshots; pass another directory as $1.
# The motives, captions, the optional second phone (light + dark) and the
# enlarged excerpt ("pop") are listed in store/ios/screenshots.tsv.
# Needs google-chrome (headless) and python3 with Pillow; the frame loads
# Fredoka and Roboto from Google Fonts, so it needs network access.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
raw_dir="${1:-$root/build/ios_screenshots}"
out="$root/store/ios"
width=1320 height=2868

urlencode() { python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$1"; }
# Rendered at 2x and halved with Lanczos, like the Play graphics: drawn at
# scale 1, text and the scaled raw shot come out blurry.
shrink() { python3 -c "from PIL import Image; import sys; Image.open(sys.argv[1]).convert('RGB').resize((int(sys.argv[2]), int(sys.argv[3])), Image.LANCZOS).save(sys.argv[1], optimize=True)" "$@"; }

# The phone draws the raw shot at 904 px (733 in a pair), the page renders at
# 2x: the shot is resized once with Lanczos to twice that so Chrome draws it 1:1.
fit() { python3 -c "
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert('RGB')
w = int(sys.argv[3])
if im.width != w: im = im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)
im.save(sys.argv[2])" "$@"; }
# Crops x,y,w,h (raw px) and scales it to w*scale x h*scale canvas px at 2x.
excerpt() { python3 -c "
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert('RGB')
x, y, w, h, s = map(float, sys.argv[3].split(',')[:5])
im = im.crop((round(x), round(y), round(x + w), round(y + h)))
im.resize((round(w * s * 2), round(h * s * 2)), Image.LANCZOS).save(sys.argv[2])" "$@"; }
prep="$root/build/ios_store_frames"
mkdir -p "$prep"

for lang in en de; do
  mkdir -p "$out/screenshots/$lang"
  rm -f "$out/screenshots/$lang"/*.png
  while IFS=$'\t' read -r name raw raw2 bg pop en_tag en_title en_sub de_tag de_title de_sub; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    tag="$en_tag" title="$en_title" sub="$en_sub"
    [[ "$lang" == de ]] && { tag="$de_tag" title="$de_title" sub="$de_sub"; }
    shot="$raw_dir/${lang}_$raw.png"
    [[ -f "$shot" ]] || { echo "missing raw shot $shot" >&2; exit 1; }
    png="$out/screenshots/$lang/$name.png"
    fitw=1880; [[ "$raw2" != - ]] && fitw=1560
    fit "$shot" "$prep/${lang}_$name.png" "$fitw"
    url="file://$out/screenshot_frame.html?bg=$bg&img=$(urlencode "$prep/${lang}_$name.png")"
    url+="&tag=$(urlencode "$tag")&title=$(urlencode "$title")&sub=$(urlencode "$sub")"
    if [[ "$raw2" != - ]]; then
      shot2="$raw_dir/${lang}_$raw2.png"
      [[ -f "$shot2" ]] || { echo "missing raw shot $shot2" >&2; exit 1; }
      fit "$shot2" "$prep/${lang}_${name}_2.png" "$fitw"
      url+="&img2=$(urlencode "$prep/${lang}_${name}_2.png")"
    fi
    if [[ "$pop" != - ]]; then
      excerpt "$shot" "$prep/${lang}_${name}_pop.png" "$pop"
      url+="&pop=$pop&popimg=$(urlencode "$prep/${lang}_${name}_pop.png")"
    fi
    google-chrome --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=2 \
      --window-size=$width,$height --virtual-time-budget=5000 \
      --screenshot="$png" "$url" 2>/dev/null
    shrink "$png" $width $height
  done < "$out/screenshots.tsv"
done
ls -l "$out"/screenshots/*/*.png
