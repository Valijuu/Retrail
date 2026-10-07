#!/usr/bin/env bash
# Builds the signed Play App Bundle and stores it as release/retrail-<version>.aab
# (release/ is gitignored — bundles never go into the public repo).
# Refuses to finish if the bundle is not signed with the upload key.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

version="$(sed -n 's/^version: *//p' pubspec.yaml)"
flutter build appbundle --release

aab=build/app/outputs/bundle/release/app-release.aab
owner="$(keytool -printcert -jarfile "$aab" 2>/dev/null | grep -m1 -E 'Owner|Eigentümer' || true)"
if [[ "$owner" != *"CN=Valijuu"* ]]; then
  echo "Bundle is not signed with the upload key: ${owner:-no certificate}" >&2
  exit 1
fi

mkdir -p release
out="release/retrail-$version.aab"
cp "$aab" "$out"
echo "$out  ($owner)"
