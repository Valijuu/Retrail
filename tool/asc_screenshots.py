#!/usr/bin/env python3
"""Compares the App Store screenshots in store/ios with App Store Connect and replaces a set that differs.

    python3 tool/asc_screenshots.py            dry run: shows the store order next to the repo files
    python3 tool/asc_screenshots.py --apply    replaces each differing set in the editable version

A set (one language, one display type) is compared by the ordered MD5 checksums of its images;
only a set that differs is replaced: its images are deleted, then the repo files are uploaded in
file-name order. Files in NOT_IN_STORE stay in the repo only. Without an editable version the
dry run reads the live version and --apply does nothing. It never submits for review.
API access: tool/asc_api.py.
"""
import hashlib
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from asc_api import LANGS, Api, describe, editable, locale_lang  # noqa: E402

IOS = Path(__file__).resolve().parent.parent / "store" / "ios"
# Repo folder -> App Store display type. The store holds only the 6.3-inch images (1206 x 2622),
# which App Store Connect files under APP_IPHONE_61; the 6.9-inch folder is not uploaded.
FOLDERS = {"screenshots_6_3": "APP_IPHONE_61"}
# Rendered but left out of the store by choice (the store order is the file order).
NOT_IN_STORE = {"10_detail.png"}
MAX_PER_SET = 10


def md5(path):
    return hashlib.md5(path.read_bytes()).hexdigest()


def store_files(folder, lang):
    files = [p for p in sorted((IOS / folder / lang).glob("*.png")) if p.name not in NOT_IN_STORE]
    return files[:MAX_PER_SET]


def upload(api, set_id, path):
    data = path.read_bytes()
    created = api.call("POST", "/appScreenshots", {"data": {
        "type": "appScreenshots",
        "attributes": {"fileName": path.name, "fileSize": len(data)},
        "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}},
    }})["data"]
    for operation in created["attributes"]["uploadOperations"]:
        chunk = data[operation["offset"]: operation["offset"] + operation["length"]]
        request = urllib.request.Request(operation["url"], data=chunk, method=operation["method"])
        for header in operation.get("requestHeaders") or []:
            request.add_header(header["name"], header["value"])
        with urllib.request.urlopen(request, timeout=120):
            pass
    api.call("PATCH", f"/appScreenshots/{created['id']}", {"data": {
        "type": "appScreenshots", "id": created["id"],
        "attributes": {"uploaded": True, "sourceFileChecksum": md5(path)},
    }})


def sync_set(api, localization, display_type, files, apply):
    locale = localization["attributes"]["locale"]
    sets = api.call("GET", f"/appStoreVersionLocalizations/{localization['id']}/appScreenshotSets")["data"]
    shot_set = next((s for s in sets if s["attributes"]["screenshotDisplayType"] == display_type), None)
    shots = []
    if shot_set:
        shots = api.call("GET", f"/appScreenshotSets/{shot_set['id']}/appScreenshots", query={"limit": 50})["data"]
    remote = [(s["attributes"].get("sourceFileChecksum") or "").lower() for s in shots]
    local = [md5(f) for f in files]
    names = {checksum: f.name for checksum, f in zip(local, files)}
    print(f"  {locale} {display_type}: store {len(remote)} images, repo {len(local)} files")
    for position, (shot, checksum) in enumerate(zip(shots, remote), 1):
        print(f"      {position}. {shot['attributes'].get('fileName')}: {names.get(checksum, 'not in repo')}")
    if not files:
        print(f"      -> no repo files for {locale}, skipped (never empties a store set)")
        return 0
    if remote == local:
        return 0
    print(f"      -> differs{', replacing' if apply else ''}")
    if apply:
        if shot_set is None:
            shot_set = api.call("POST", "/appScreenshotSets", {"data": {
                "type": "appScreenshotSets",
                "attributes": {"screenshotDisplayType": display_type},
                "relationships": {"appStoreVersionLocalization": {
                    "data": {"type": "appStoreVersionLocalizations", "id": localization["id"]}}},
            }})["data"]
        for shot in shots:
            api.call("DELETE", f"/appScreenshots/{shot['id']}")
        for path in files:
            upload(api, shot_set["id"], path)
    return 1


def main():
    apply = "--apply" in sys.argv[1:]
    api = Api.from_env()
    versions = api.versions(api.app_id())
    open_versions = editable(versions)
    if not versions:
        raise SystemExit("No iOS version in App Store Connect")
    if apply and not open_versions:
        print("No editable version: screenshots cannot change. Upload a build first.")
        return 0
    version = (open_versions or versions)[0]
    print(f"{'APPLY' if apply else 'DRY RUN'}: screenshots of version {describe(version)}"
          + ("" if open_versions else ", read only (not editable)"))

    changed = 0
    for localization in api.version_localizations(version["id"]):
        lang = locale_lang(localization["attributes"]["locale"])
        if lang not in LANGS:
            continue
        for folder, display_type in FOLDERS.items():
            changed += sync_set(api, localization, display_type, store_files(folder, lang), apply)
    verb = "replaced" if apply else "would be replaced"
    print(f"Done: {changed} set(s) {verb}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
