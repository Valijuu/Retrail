"""App Store Connect API access shared by tool/asc_sync.py (texts) and tool/asc_screenshots.py.

Stdlib only; the ES256 token is signed with the openssl CLI. Reads ASC_KEY_ID, ASC_ISSUER_ID and
ASC_KEY_FILE (path to the .p8 key of the App Manager API key).
"""
import base64
import json
import os
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request

BUNDLE_ID = "io.github.valijuu.retrail"
API = "https://api.appstoreconnect.apple.com/v1"
LANGS = ("de", "en")
# Versions that still accept edits of texts and screenshots.
EDITABLE_STATES = {
    "PREPARE_FOR_SUBMISSION",
    "DEVELOPER_REJECTED",
    "REJECTED",
    "METADATA_REJECTED",
    "INVALID_BINARY",
}


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

    @classmethod
    def from_env(cls):
        return cls(make_token(os.environ["ASC_KEY_ID"], os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_FILE"]))

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

    def app_id(self):
        apps = self.call("GET", "/apps", query={"filter[bundleId]": BUNDLE_ID})["data"]
        if not apps:
            raise SystemExit(f"No app with bundle id {BUNDLE_ID} visible to this key")
        return apps[0]["id"]

    def versions(self, app_id):
        """iOS versions, newest first (by creation date)."""
        versions = self.call(
            "GET", f"/apps/{app_id}/appStoreVersions", query={"filter[platform]": "IOS", "limit": 200}
        )["data"]
        return sorted(versions, key=lambda v: v["attributes"].get("createdDate") or "", reverse=True)

    def version_localizations(self, version_id):
        return self.call(
            "GET", f"/appStoreVersions/{version_id}/appStoreVersionLocalizations", query={"limit": 50}
        )["data"]


def editable(versions):
    return [v for v in versions if v["attributes"]["appStoreState"] in EDITABLE_STATES]


def locale_lang(locale):
    return locale.split("-")[0].lower()


def describe(version):
    return f"{version['attributes']['versionString']} ({version['attributes']['appStoreState']})"
