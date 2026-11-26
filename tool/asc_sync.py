#!/usr/bin/env python3
"""Compares the App Store texts in store/ios/text with App Store Connect and updates what differs.

    python3 tool/asc_sync.py            dry run: only prints which fields would change
    python3 tool/asc_sync.py --apply    writes the changed fields

Needs ASC_KEY_ID, ASC_ISSUER_ID and the key file path in ASC_KEY_FILE (the App Manager API
key of the iOS workflows). Stdlib only; the ES256 token is signed with the openssl CLI.
Only fields whose file differs from the store are written. It never submits for review
and never creates a version or a localization: a missing one is reported and skipped.
"""
import base64
import hashlib
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

BUNDLE_ID = "io.github.valijuu.retrail"
API = "https://api.appstoreconnect.apple.com/v1"
TEXT_DIR = Path(__file__).resolve().parent.parent / "store" / "ios" / "text"
LANGS = ("de", "en")
# Versions that still accept text edits.
EDITABLE_STATES = {
    "PREPARE_FOR_SUBMISSION",
    "DEVELOPER_REJECTED",
    "REJECTED",
    "METADATA_REJECTED",
    "INVALID_BINARY",
}
# file key -> API field, per resource.
VERSION_FIELDS = {
    "description": "description",
    "keywords": "keywords",
    "promo": "promotionalText",
    "whatsnew": "whatsNew",
}
INFO_FIELDS = {"name": "name", "subtitle": "subtitle"}


def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def der_to_raw(der):
    """ECDSA DER signature -> r||s (32 bytes each), as JWT ES256 wants it."""
    pos = 2 + (der[1] - 0x80 if der[1] & 0x80 else 0)
    parts = []
    for _ in range(2):
        length = der[pos + 1]
        value = der[pos + 2 : pos + 2 + length].lstrip(b"\x00")
        parts.append(value.rjust(32, b"\x00"))
        pos += 2 + length
    return b"".join(parts)


def make_token(key_id, issuer, key_file):
    header = b64url(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}).encode())
    now = int(time.time())
    claims = b64url(
        json.dumps({"iss": issuer, "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"}).encode()
    )
    signing_input = f"{header}.{claims}".encode()
    der = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", key_file],
        input=signing_input,
        capture_output=True,
        check=True,
    ).stdout
    return f"{header}.{claims}.{b64url(der_to_raw(der))}"


class Api:
    def __init__(self, token):
        self.token = token

    def call(self, method, path, body=None, query=None):
        url = API + path + ("?" + urllib.parse.urlencode(query) if query else "")
        data = json.dumps(body).encode() if body is not None else None
        request = urllib.request.Request(url, data=data, method=method)
        request.add_header("Authorization", f"Bearer {self.token}")
        if data:
            request.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                raw = response.read()
        except urllib.error.HTTPError as error:
            detail = error.read().decode(errors="replace")[:600]
            raise SystemExit(f"{method} {path} -> HTTP {error.code}: {detail}")
        return json.loads(raw) if raw else {}


def read_texts():
    texts = {}
    for lang in LANGS:
        for key in (*VERSION_FIELDS, *INFO_FIELDS):
            path = TEXT_DIR / f"{lang}_{key}.txt"
            if path.is_file():
                texts[(lang, key)] = path.read_text(encoding="utf-8").strip()
    return texts


def locale_lang(locale):
    return locale.split("-")[0].lower()


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


def report_screenshot_order(api, version):
    """Read-only: lists the uploaded screenshots per language and display type in store order and
    names the repo file with the same MD5 (sourceFileChecksum), so a reorder or a stale image shows."""
    ios = TEXT_DIR.parent
    local = {}
    for folder in ("screenshots", "screenshots_6_3"):
        for lang in LANGS:
            for path in sorted((ios / folder / lang).glob("*.png")):
                local[(lang, hashlib.md5(path.read_bytes()).hexdigest())] = f"{folder}/{path.name}"
    print(f"Screenshot order in version {version['attributes']['versionString']} "
          f"({version['attributes']['appStoreState']}), read only:")
    items = api.call("GET", f"/appStoreVersions/{version['id']}/appStoreVersionLocalizations", query={"limit": 50})["data"]
    for item in items:
        lang = locale_lang(item["attributes"]["locale"])
        sets = api.call("GET", f"/appStoreVersionLocalizations/{item['id']}/appScreenshotSets")["data"]
        for shot_set in sets:
            shots = api.call("GET", f"/appScreenshotSets/{shot_set['id']}/appScreenshots", query={"limit": 50})["data"]
            print(f"  {item['attributes']['locale']} {shot_set['attributes']['screenshotDisplayType']}: {len(shots)} images")
            for position, shot in enumerate(shots, 1):
                checksum = (shot["attributes"].get("sourceFileChecksum") or "").lower()
                match = local.get((lang, checksum), "not in repo")
                print(f"      {position}. {shot['attributes'].get('fileName')}: {match}")


def main():
    apply = "--apply" in sys.argv[1:]
    token = make_token(os.environ["ASC_KEY_ID"], os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_FILE"])
    api = Api(token)
    texts = read_texts()
    print(f"{'APPLY' if apply else 'DRY RUN'}: {len(texts)} text files read")

    apps = api.call("GET", "/apps", query={"filter[bundleId]": BUNDLE_ID})["data"]
    if not apps:
        raise SystemExit(f"No app with bundle id {BUNDLE_ID} visible to this key")
    app_id = apps[0]["id"]

    changed = 0
    versions = api.call("GET", f"/apps/{app_id}/appStoreVersions", query={"filter[platform]": "IOS", "limit": 10})["data"]
    editable = [v for v in versions if v["attributes"]["appStoreState"] in EDITABLE_STATES]
    if editable:
        version = editable[0]
        print(f"Version {version['attributes']['versionString']} ({version['attributes']['appStoreState']})")
        items = api.call("GET", f"/appStoreVersions/{version['id']}/appStoreVersionLocalizations", query={"limit": 50})["data"]
        changed += sync_localizations(api, "version", items, VERSION_FIELDS, texts, "appStoreVersionLocalizations", apply)
    else:
        states = ", ".join(sorted({v["attributes"]["appStoreState"] for v in versions})) or "none"
        print(f"No editable version (states: {states}): version texts skipped. "
              "Upload a build or create the next version first.")

    if not apply and versions:
        report_screenshot_order(api, (editable or versions)[0])

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
