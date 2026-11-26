#!/usr/bin/env python3
"""Compares the App Store texts in store/ios/text with App Store Connect and updates what differs.

    python3 tool/asc_sync.py            dry run: only prints which fields would change
    python3 tool/asc_sync.py --apply    writes the changed fields

API access: tool/asc_api.py. Screenshots: tool/asc_screenshots.py.
Only fields whose file differs from the store are written. It never submits for review
and never creates a version or a localization: a missing one is reported and skipped.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from asc_api import LANGS, Api, describe, editable, EDITABLE_STATES, locale_lang  # noqa: E402

TEXT_DIR = Path(__file__).resolve().parent.parent / "store" / "ios" / "text"
# file key -> API field, per resource.
VERSION_FIELDS = {
    "description": "description",
    "keywords": "keywords",
    "promo": "promotionalText",
    "whatsnew": "whatsNew",
}
INFO_FIELDS = {"name": "name", "subtitle": "subtitle"}


def read_texts():
    texts = {}
    for lang in LANGS:
        for key in (*VERSION_FIELDS, *INFO_FIELDS):
            path = TEXT_DIR / f"{lang}_{key}.txt"
            if path.is_file():
                texts[(lang, key)] = path.read_text(encoding="utf-8").strip()
    return texts


def sync_localizations(api, label, items, fields, texts, resource, apply):
    """items: localization resources of one version / app info. Returns number of changed fields."""
    changed = 0
    seen = set()
    for item in items:
        lang = locale_lang(item["attributes"]["locale"])
        if lang not in LANGS:
            continue
        seen.add(lang)
        update = {}
        for key, field in fields.items():
            wanted = texts.get((lang, key))
            if wanted is None:
                continue
            current = (item["attributes"].get(field) or "").strip()
            if current != wanted:
                update[field] = wanted
                print(f"  {label} {item['attributes']['locale']}: {field} differs "
                      f"(store {len(current)} chars, file {len(wanted)} chars)")
        if update and apply:
            api.call("PATCH", f"/{resource}/{item['id']}",
                     {"data": {"type": resource, "id": item["id"], "attributes": update}})
        changed += len(update)
    for lang in LANGS:
        if lang not in seen:
            print(f"  {label}: no '{lang}' localization in App Store Connect, skipped (add it there once)")
    return changed


def main():
    apply = "--apply" in sys.argv[1:]
    api = Api.from_env()
    texts = read_texts()
    print(f"{'APPLY' if apply else 'DRY RUN'}: {len(texts)} text files read")
    app_id = api.app_id()

    changed = 0
    versions = api.versions(app_id)
    open_versions = editable(versions)
    if open_versions:
        version = open_versions[0]
        print(f"Version {describe(version)}")
        items = api.version_localizations(version["id"])
        changed += sync_localizations(api, "version", items, VERSION_FIELDS, texts, "appStoreVersionLocalizations", apply)
    else:
        states = ", ".join(sorted({v["attributes"]["appStoreState"] for v in versions})) or "none"
        print(f"No editable version (states: {states}): version texts skipped. "
              "Upload a build or create the next version first.")

    infos = api.call("GET", f"/apps/{app_id}/appInfos")["data"]
    editable_infos = [i for i in infos if i["attributes"].get("appStoreState") in EDITABLE_STATES]
    if editable_infos:
        items = api.call("GET", f"/appInfos/{editable_infos[0]['id']}/appInfoLocalizations", query={"limit": 50})["data"]
        changed += sync_localizations(api, "app info", items, INFO_FIELDS, texts, "appInfoLocalizations", apply)
    else:
        print("No editable app info: name and subtitle skipped.")

    verb = "written" if apply else "would change"
    print(f"Done: {changed} field(s) {verb}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
