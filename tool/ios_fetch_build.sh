#!/usr/bin/env bash
# Downloads the newest green iOS build (GitHub Actions "iOS build" on main) to
# ~/Downloads/retrail-ios/Retrail.ipa.7z, replacing the previous one, and shows a
# desktop notification. Does nothing if that build is already there.
#
#   tool/ios_fetch_build.sh            fetch the latest green build (if new)
#   tool/ios_fetch_build.sh --wait     wait for the build running on main (started by a
#                                      push or "Run workflow" on GitHub), then fetch it
#   tool/ios_fetch_build.sh --trigger  start a new build on main, wait, then fetch
#
# The archive stays encrypted: unpack with `7z x Retrail.ipa.7z` (IPA_PASSWORD),
# then `splice install Retrail.ipa` — see docs/ios-sideloading.md.
set -euo pipefail

REPO="Valijuu/Retrail"
WORKFLOW="ios-build.yml"
BRANCH="main"
DEST="${RETRAIL_IOS_DIR:-$HOME/Downloads/retrail-ios}"
STATE="$DEST/.artifact-id"
SCRIPT="$(readlink -f "$0")"

# A build takes a few seconds to show up after a push / "Run workflow".
APPEAR_TIMEOUT_S=60
APPEAR_POLL_S=5

log() { printf '%s %s\n' "$(date '+%H:%M:%S')" "$*"; }

notify() {
  command -v notify-send >/dev/null 2>&1 && notify-send -a Retrail "$1" "$2" || true
}

latest_green_run() {
  gh run list -R "$REPO" --workflow "$WORKFLOW" --branch "$BRANCH" --status success \
    --limit 1 --json databaseId,number,displayTitle \
    --jq '.[0] | "\(.databaseId)\t\(.number)\t\(.displayTitle)"'
}

fetch() {
  local run run_id run_no title artifact
  run="$(latest_green_run)"
  if [ -z "$run" ]; then log "No green iOS build on $BRANCH yet."; return 0; fi
  IFS=$'\t' read -r run_id run_no title <<<"$run"

  artifact="$(gh api "repos/$REPO/actions/runs/$run_id/artifacts" \
    --jq '[.artifacts[] | select(.expired == false)][0].id // empty')"
  if [ -z "$artifact" ]; then log "Build #$run_no has no (unexpired) artifact."; return 0; fi

  mkdir -p "$DEST"
  if [ "$(cat "$STATE" 2>/dev/null)" = "$artifact" ]; then
    log "Build #$run_no is already in $DEST."
    return 0
  fi

  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  gh api "repos/$REPO/actions/artifacts/$artifact/zip" > "$tmp/artifact.zip"
  unzip -q -o "$tmp/artifact.zip" -d "$tmp"
  [ -f "$tmp/Retrail.ipa.7z" ] || { log "Artifact has no Retrail.ipa.7z."; return 1; }

  # Replace the old build: the encrypted archive and anything unpacked from it.
  rm -rf "$DEST/Retrail.ipa" "$DEST/dist"
  mv -f "$tmp/Retrail.ipa.7z" "$DEST/Retrail.ipa.7z"
  printf '%s\n' "$artifact" > "$STATE"

  log "Build #$run_no ($title) → $DEST/Retrail.ipa.7z"
  notify "Retrail iOS build #$run_no ready" "$title — $DEST/Retrail.ipa.7z"
}

# Waits for run [run_id] to finish; fetches it when green.
watch_and_fetch() {
  local run_id="$1"
  log "Waiting for build $run_id (about 15 min)…"
  if gh run watch "$run_id" -R "$REPO" --exit-status --interval 30 >/dev/null; then
    fetch
  else
    log "Build $run_id failed: https://github.com/$REPO/actions/runs/$run_id"
    notify "Retrail iOS build failed" "https://github.com/$REPO/actions/runs/$run_id"
    return 1
  fi
}

# Prints the id of the newest queued / running build on $BRANCH that matches the
# extra jq filter [$1] (e.g. a creation-time bound), polling until one appears or
# APPEAR_TIMEOUT_S passes. Prints nothing if none shows up.
find_running_run() {
  local filter="${1:-true}" run_id=""
  for _ in $(seq 1 $((APPEAR_TIMEOUT_S / APPEAR_POLL_S))); do
    run_id="$(gh run list -R "$REPO" --workflow "$WORKFLOW" --branch "$BRANCH" \
      --limit 5 --json databaseId,status,createdAt \
      --jq "[.[] | select(.status != \"completed\") | select($filter)][0].databaseId // empty")"
    [ -n "$run_id" ] && break
    sleep "$APPEAR_POLL_S"
  done
  printf '%s' "$run_id"
}

# --wait: the build a push or GitHub's "Run workflow" started, whatever triggered it.
wait_for_running() {
  local run_id
  log "Looking for a running iOS build on $BRANCH…"
  run_id="$(find_running_run)"
  if [ -z "$run_id" ]; then
    log "No build is running — fetching the latest green one."
    fetch
    return
  fi
  watch_and_fetch "$run_id"
}

# --trigger: start a build ourselves, then wait for exactly that one.
trigger() {
  local started run_id
  started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  gh workflow run "$WORKFLOW" -R "$REPO" --ref "$BRANCH"
  log "Build started on $BRANCH."
  run_id="$(find_running_run ".createdAt >= \"$started\"")"
  [ -n "$run_id" ] || { log "The started build did not appear."; return 1; }
  watch_and_fetch "$run_id"
}

case "${1:-}" in
  "") fetch ;;
  --wait) wait_for_running ;;
  --trigger) trigger ;;
  *) sed -n '2,12p' "$SCRIPT"; exit 2 ;;
esac
