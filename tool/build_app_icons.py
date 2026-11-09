#!/usr/bin/env python3
"""Builds the branding PNGs from the logo source (R on a dark tile).

Source: assets/branding/source/retrail_logo_tile.png. The R is lifted off the tile with soft edges;
the launcher icon puts it back on the tile's dark brown gradient, the in-app mark stays bare. Writes into assets/branding/ and the platform assets
that are not made by flutter_launcher_icons (Android splash and status-bar glyph, iOS Live
Activity mark). Then run `dart run flutter_launcher_icons` for the launcher icons.
Needs python3 with Pillow only.
"""
import math
import os
import sys
from PIL import Image, ImageChops, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SRC = f"{ROOT}/assets/branding/source/retrail_logo_tile.png"
RES = f"{ROOT}/android/app/src/main/res"
IOS_MARK = f"{ROOT}/ios/RideActivityExtension/Assets.xcassets/RetrailMark.imageset"

CANVAS = 1024
SAFE_RADIUS = CANVAS * 33 / 108  # 66 dp safe zone of the 108 dp adaptive canvas
BG = (40, 19, 9)  # tile colour near the R, used to un-mix the soft edge
# Box around the R inside the source; the tile's own edge and the white margin stay outside.
UPSCALE = 3  # the source R is only ~380 px wide; the mark is smoothed at 3x
R_BOX = (400, 320, 860, 840)
TILE_TOP, TILE_BOTTOM = (54, 28, 11), (36, 18, 8)  # tile gradient sampled from the source
LINE_ALPHA = 0.35  # white pin/route line in the monochrome silhouette
FG_FILL = 0.87  # share of the safe-zone radius the adaptive mark uses, so it does not touch the edge
ICON_FILL = 0.56  # mark height as a share of the full-bleed icon


def clamp(v):
    return max(0, min(255, int(v)))


def extract_mark():
    """Returns the R as a tight-cropped RGBA image at source resolution."""
    rgb = Image.open(SRC).convert("RGB").crop(R_BOX)
    r, _, b = rgb.split()
    # Orange and white parts stand out by red; the darkest brown shade of the R is as dark as the
    # tile in red, but has no blue (the tile keeps a little).
    a_red = r.point(lambda v: clamp((v - 62) * 255 / 22))
    r_minus_b = ImageChops.subtract(r, b.point(lambda v: clamp(4 * v)))
    a_shade = r_minus_b.point(lambda v: clamp((v - 30) * 255 / 20))
    alpha = ImageChops.lighter(a_red, a_shade)
    # Colour of the soft edge pixels is mixed with the dark tile (the black rim on a light ground).
    # Take the colour from the solid pixels next to them instead, and keep only the coverage.
    solid = alpha.point(lambda v: 255 if v >= 250 else 0).filter(ImageFilter.MinFilter(5))
    filled = bleed(rgb, solid, 3)
    filled = bleed(filled, filled_mask(filled, solid, 3), 9)
    # Smooth, round edges: upsample the coverage, blur it and sharpen it around the half level.
    up = UPSCALE
    size = (rgb.width * up, rgb.height * up)
    cov = alpha.resize(size, Image.BICUBIC).filter(ImageFilter.GaussianBlur(up * 0.9))
    cov = cov.point(lambda v: clamp((v - 138) * 4 + 128))
    out = filled.resize(size, Image.BICUBIC).convert("RGBA")
    out.putalpha(cov)
    return out.crop(cov.point(lambda v: 255 if v > 8 else 0).getbbox())


def bleed(rgb, solid, radius):
    """Fills every pixel outside `solid` with the mean colour of the solid pixels nearby."""
    box = ImageFilter.BoxBlur(radius)
    mask = solid.point(lambda v: 1 if v else 0)
    num = [ImageChops.multiply(ch, solid).filter(box) for ch in rgb.split()]
    den = solid.filter(box)
    out = rgb.copy()
    op, sp, dp = out.load(), solid.load(), den.load()
    nps = [n.load() for n in num]
    for y in range(rgb.height):
        for x in range(rgb.width):
            if not sp[x, y] and dp[x, y]:
                d = dp[x, y]
                op[x, y] = tuple(clamp(nps[i][x, y] * 255 / d) for i in range(3))
    return out


def filled_mask(img, solid, radius):
    """Solid pixels plus the ones `bleed` has just filled."""
    return solid.filter(ImageFilter.MaxFilter(2 * radius + 1))


def scaled(img, factor):
    return img.resize((round(img.width * factor), round(img.height * factor)), Image.LANCZOS)


def farthest(img):
    """Largest distance of an opaque pixel from the image centre."""
    a = img.getchannel("A").point(lambda v: 255 if v > 128 else 0)
    cx, cy = img.width / 2, img.height / 2
    px = a.load()
    best = 0.0
    for y in range(img.height):
        for x in range(img.width):
            if px[x, y]:
                best = max(best, math.hypot(x + 0.5 - cx, y + 0.5 - cy))
    return best


def centred(img, size=CANVAS, bg=None):
    canvas = Image.new("RGBA", (size, size), bg or (0, 0, 0, 0))
    canvas.alpha_composite(img, ((size - img.width) // 2, (size - img.height) // 2))
    return canvas


def silhouette(img, line_alpha=LINE_ALPHA):
    """White glyph; the white pin and route line stay as a faint inner drawing."""
    out = Image.new("RGBA", img.size, (255, 255, 255, 0))
    px, op = img.load(), out.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a:
                op[x, y] = (255, 255, 255, round(a * (line_alpha if min(r, g, b) > 200 else 1)))
    return out


def fit_square(img, size):
    s = size / max(img.size)
    return centred(scaled(img, s), size)


def tile_gradient():
    """The tile's vertical gradient as a full-bleed square."""
    col = Image.new("RGB", (1, CANVAS))
    for y in range(CANVAS):
        t = y / (CANVAS - 1)
        col.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(TILE_TOP, TILE_BOTTOM)))
    return col.resize((CANVAS, CANVAS))


def save(img, path, flat_on=None):
    if flat_on:
        flat = Image.new("RGB", img.size, flat_on)
        flat.paste(img, mask=img.getchannel("A"))
        img = flat
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)
    print("wrote", os.path.relpath(path, ROOT))


def main():
    mark = extract_mark()
    # Launcher mark: the farthest mark pixel sits at FG_FILL of the 66 dp safe-zone radius (no extra inset).
    fg_mark = scaled(mark, FG_FILL * SAFE_RADIUS / farthest(mark))
    foreground = centred(fg_mark)
    save(foreground, f"{ROOT}/assets/branding/app_icon_foreground.png")
    save(centred(silhouette(fg_mark)), f"{ROOT}/assets/branding/app_icon_monochrome.png")
    # Adaptive background and full-bleed icon (iOS, Play store): the same mark, bigger than the
    # adaptive one, on the tile gradient.
    ground = tile_gradient()
    save(ground, f"{ROOT}/assets/branding/app_icon_background.png")
    ios_mark = scaled(mark, ICON_FILL * CANVAS / mark.height)
    icon = ground.convert("RGBA")
    icon.alpha_composite(centred(ios_mark))
    save(icon.convert("RGB"), f"{ROOT}/assets/branding/app_icon.png")
    # The only image the app bundles: tight crop at 2x for 3x screens.
    save(scaled(mark, 2 / UPSCALE), f"{ROOT}/assets/branding/retrail_mark.png")
    # Android 12+ splash icon: the launcher foreground, 240 dp per density.
    for dens, px in (("mdpi", 240), ("hdpi", 360), ("xhdpi", 480), ("xxhdpi", 720), ("xxxhdpi", 960)):
        save(foreground.resize((px, px), Image.LANCZOS), f"{RES}/drawable-{dens}/splash_icon.png")
    # Status-bar glyph of the recording notification: white silhouette, 24 dp per density.
    glyph = silhouette(mark)
    for dens, px in (("mdpi", 24), ("hdpi", 36), ("xhdpi", 48), ("xxhdpi", 72), ("xxxhdpi", 96)):
        save(fit_square(glyph, px), f"{RES}/drawable-{dens}/ic_stat_retrail.png")
    # iOS Live Activity mark: 24 pt at 1x to 3x.
    for scale in (1, 2, 3):
        save(fit_square(mark, 24 * scale), f"{IOS_MARK}/retrail_mark@{scale}x.png")


if __name__ == "__main__":
    sys.exit(main())
