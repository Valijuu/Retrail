#!/usr/bin/env python3
"""Compares the Play listing in store/play with Google Play and updates what differs.

    python3 tool/play_listing_sync.py            dry run: prints what would change, commits nothing
    python3 tool/play_listing_sync.py --apply    writes the changes and commits the edit

Needs PLAY_SERVICE_ACCOUNT_FILE (the service account JSON of the release workflow).
Stdlib only; the RS256 token is signed with the openssl CLI.

Texts: short and full description per language. Images: phone screenshots, feature graphic
and icon are compared by SHA-256 with what Play holds, and a group is replaced (delete all,
upload in file order) only when it differs. Nothing else is touched: no title, no video, no
data-safety forms. A language that is not set up in the Play Console is reported and skipped.
"""
import base64
import hashlib
import json
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import os
import tempfile
from pathlib import Path

PACKAGE = "io.github.valijuu.retrail"
ROOT = Path(__file__).resolve().parent.parent
PLAY = ROOT / "store" / "play"
LANGS = {"de": "de-DE", "en": "en-US"}
API = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PACKAGE}"
UPLOAD = f"https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{PACKAGE}"


def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def access_token(account):
    now = int(time.time())
    header = b64url(json.dumps({"alg": "RS256", "typ": "JWT"}).encode())
    claims = b64url(json.dumps({
        "iss": account["client_email"],
        "scope": "https://www.googleapis.com/auth/androidpublisher",
        "aud": "https://oauth2.googleapis.com/token",
        "iat": now,
        "exp": now + 1800,
    }).encode())
    # openssl reads the key from a private temp file; the message goes in on stdin.
    with tempfile.NamedTemporaryFile("w", delete=False) as handle:
        os.chmod(handle.name, 0o600)
        handle.write(account["private_key"])
        path = handle.name
    try:
        signature = subprocess.run(
            ["openssl", "dgst", "-sha256", "-sign", path],
            input=f"{header}.{claims}".encode(), capture_output=True, check=True,
        ).stdout
    finally:
        os.unlink(path)
    assertion = f"{header}.{claims}.{b64url(signature)}"
    body = urllib.parse.urlencode({
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion": assertion,
    }).encode()
    try:
        with urllib.request.urlopen(urllib.request.Request("https://oauth2.googleapis.com/token", data=body), timeout=60) as r:
            return json.loads(r.read())["access_token"]
    except urllib.error.HTTPError as error:
        raise SystemExit(
            f"Token request -> HTTP {error.code}: {error.read().decode(errors='replace')[:400]}\n"
            f"Key used: account {account.get('client_email')}, key id {account.get('private_key_id')}"
        )


class Play:
    def __init__(self, token):
        self.token = token

    def call(self, method, url, body=None, raw=None, content_type=None, allow=()):
        data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
        request = urllib.request.Request(url, data=data, method=method)
        request.add_header("Authorization", f"Bearer {self.token}")
        if data is not None:
            request.add_header("Content-Type", content_type or "application/json")
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                payload = response.read()
        except urllib.error.HTTPError as error:
            if error.code in allow:
                return None
            raise SystemExit(f"{method} {url.split('applications/')[-1]} -> HTTP {error.code}: "
                             f"{error.read().decode(errors='replace')[:500]}")
        return json.loads(payload) if payload else {}


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    apply = "--apply" in sys.argv[1:]
    account = json.loads(Path(os.environ["PLAY_SERVICE_ACCOUNT_FILE"]).read_text())
    play = Play(access_token(account))
    print("APPLY" if apply else "DRY RUN")

    edit = play.call("POST", f"{API}/edits", {})["id"]
    changes = 0
    try:
        for lang, locale in LANGS.items():
            listing = play.call("GET", f"{API}/edits/{edit}/listings/{locale}", allow=(404,))
            if listing is None:
                print(f"  {locale}: no listing in the Play Console, skipped (set the language up there once)")
                continue

            update = {}
            for key, field in (("short", "shortDescription"), ("full", "fullDescription")):
                wanted = (PLAY / "text" / f"{lang}_{key}.txt").read_text(encoding="utf-8").strip()
                if (listing.get(field) or "").strip() != wanted:
                    update[field] = wanted
                    print(f"  {locale}: {field} differs ({len(listing.get(field) or '')} -> {len(wanted)} chars)")
            if update:
                changes += len(update)
                if apply:
                    play.call("PATCH", f"{API}/edits/{edit}/listings/{locale}", update)

            groups = {
                "phoneScreenshots": sorted((PLAY / "screenshots" / lang).glob("*.png")),
                "featureGraphic": [PLAY / f"feature_graphic_{lang}.png"],
                "icon": [PLAY / "icon_512.png"],
            }
            for image_type, files in groups.items():
                remote = play.call("GET", f"{API}/edits/{edit}/listings/{locale}/{image_type}").get("images", [])
                if [i["sha256"] for i in remote] == [sha256(f) for f in files]:
                    continue
                print(f"  {locale}: {image_type} differs (Play {len(remote)} images, files {len(files)})")
                remote_hashes = [i["sha256"] for i in remote]
                for index, f in enumerate(files):
                    local = sha256(f)
                    if index < len(remote_hashes) and remote_hashes[index] == local:
                        state = "same"
                    elif local in remote_hashes:
                        state = f"same image, Play position {remote_hashes.index(local) + 1}"
                    else:
                        state = "not in Play"
                    print(f"      {index + 1}. {f.name}: {state}")
                changes += 1
                if apply:
                    play.call("DELETE", f"{API}/edits/{edit}/listings/{locale}/{image_type}")
                    for f in files:
                        play.call("POST", f"{UPLOAD}/edits/{edit}/listings/{locale}/{image_type}?uploadType=media",
                                  raw=f.read_bytes(), content_type="image/png")

        if apply and changes:
            play.call("POST", f"{API}/edits/{edit}:commit")
            print(f"Done: {changes} change(s) committed.")
        else:
            play.call("DELETE", f"{API}/edits/{edit}")
            print(f"Done: {changes} change(s) {'found' if changes else 'none'}; nothing committed.")
    except BaseException:
        play.call("DELETE", f"{API}/edits/{edit}", allow=(404, 400))
        raise
    return 0


if __name__ == "__main__":
    sys.exit(main())
