#!/usr/bin/env python3
"""Checks the store texts, release notes and image sizes against the store limits.

Run from the repo root (stdlib only):

    python3 tool/store_check.py           check everything, exit 1 on a problem
    python3 tool/store_check.py --write   also rewrite store/ios/text/{de,en}_whatsnew.txt
                                          from store/release-notes/<version>.md

store/release-notes/<version>.md is the single source for "what is new" (Play and App
Store). Limits come from store/store.sdd and the stores: Play short 80 / full 4000 /
notes 500 per language, App Store name 30 / subtitle 30 / keywords 100 / promo 170 /
description 4000 / notes 4000.
"""
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STORE = ROOT / "store"
LANGS = ("de", "en")

PLAY_TEXT_LIMITS = {"short": 80, "full": 4000}
PLAY_NOTES_LIMIT = 500
IOS_TEXT_LIMITS = {
    "name": 30,
    "subtitle": 30,
    "keywords": 100,
    "promo": 170,
    "description": 4000,
    "whatsnew": 4000,
}
# (folder, expected size) of every image the stores take.
IMAGE_SIZES = [
    (STORE / "play" / "screenshots", (1080, 1920)),
    (STORE / "ios" / "screenshots", (1320, 2868)),
    (STORE / "ios" / "screenshots_6_3", (1206, 2622)),
]
FEATURE_GRAPHIC_SIZE = (1024, 500)
PLAY_ICON_SIZE = (512, 512)


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return struct.unpack(">II", head[16:24])


def read_version():
    for line in (ROOT / "pubspec.yaml").read_text(encoding="utf-8").splitlines():
        match = re.match(r"version:\s*(\S+)", line)
        if match:
            return match.group(1)
    raise SystemExit("version: missing in pubspec.yaml")


def notes_sections(path):
    sections, current = {}, None
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.match(r"## (\w+)\s*$", line)
        if match:
            current = match.group(1)
            sections[current] = []
        elif current is not None:
            sections[current].append(line)
    return {k: "\n".join(v).strip() for k, v in sections.items()}


def check_length(problems, path, text, limit):
    if len(text) > limit:
        problems.append(f"{path.relative_to(ROOT)}: {len(text)} characters, limit {limit}")


def main():
    write = "--write" in sys.argv[1:]
    problems = []

    version = read_version()
    notes_path = STORE / "release-notes" / f"{version}.md"
    notes = {}
    if not notes_path.is_file():
        problems.append(f"{notes_path.relative_to(ROOT)} is missing (version {version} in pubspec.yaml)")
    else:
        notes = notes_sections(notes_path)
        for lang in LANGS:
            text = notes.get(lang, "")
            if not text:
                problems.append(f"{notes_path.relative_to(ROOT)}: section '## {lang}' is missing or empty")
            else:
                check_length(problems, notes_path, text, PLAY_NOTES_LIMIT)

    for lang in LANGS:
        for key, limit in PLAY_TEXT_LIMITS.items():
            path = STORE / "play" / "text" / f"{lang}_{key}.txt"
            if not path.is_file():
                problems.append(f"{path.relative_to(ROOT)} is missing")
            else:
                check_length(problems, path, path.read_text(encoding="utf-8").strip(), limit)
        for key, limit in IOS_TEXT_LIMITS.items():
            path = STORE / "ios" / "text" / f"{lang}_{key}.txt"
            if key == "whatsnew" and write and notes.get(lang):
                path.write_text(notes[lang] + "\n", encoding="utf-8")
            if not path.is_file():
                problems.append(f"{path.relative_to(ROOT)} is missing")
                continue
            text = path.read_text(encoding="utf-8").strip()
            check_length(problems, path, text, limit)
            if key == "whatsnew" and notes.get(lang) and text != notes[lang]:
                problems.append(
                    f"{path.relative_to(ROOT)} differs from {notes_path.name}; "
                    "run: python3 tool/store_check.py --write"
                )

    for folder, expected in IMAGE_SIZES:
        for lang in LANGS:
            for path in sorted((folder / lang).glob("*.png")):
                if png_size(path) != expected:
                    problems.append(f"{path.relative_to(ROOT)}: {png_size(path)}, expected {expected}")
    for lang in LANGS:
        path = STORE / "play" / f"feature_graphic_{lang}.png"
        if png_size(path) != FEATURE_GRAPHIC_SIZE:
            problems.append(f"{path.relative_to(ROOT)}: {png_size(path)}, expected {FEATURE_GRAPHIC_SIZE}")
    icon = STORE / "play" / "icon_512.png"
    if png_size(icon) != PLAY_ICON_SIZE:
        problems.append(f"{icon.relative_to(ROOT)}: {png_size(icon)}, expected {PLAY_ICON_SIZE}")

    if problems:
        print("Store check failed:")
        for problem in problems:
            print(f"  - {problem}")
        return 1
    print(f"Store check ok (version {version}).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
