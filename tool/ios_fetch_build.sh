#!/usr/bin/env bash
# Downloads the newest green iOS build (GitHub Actions "iOS build" on main) to
# ~/Downloads/retrail-ios/Retrail.ipa.7z, replacing the previous one, and shows a
# desktop notification. Does nothing if that build is already there.
#
#   tool/ios_fetch_build.sh            fetch the latest green build (if new)
#   tool/ios_fetch_build.sh --trigger  start a new build on main, wait, then fetch
#   tool/ios_fetch_build.sh --install-timer / --remove-timer
#                                      check automatically every 5 min (systemd user timer)
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
UNIT_DIR="$HOME/.config/systemd/user"
UNIT_NAME="retrail-ios-fetch"

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

trigger() {
  local started run_id
  started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  gh workflow run "$WORKFLOW" -R "$REPO" --ref "$BRANCH"
  log "Build started on $BRANCH, waiting for it to show up…"
  for _ in $(seq 1 30); do
    run_id="$(gh run list -R "$REPO" --workflow "$WORKFLOW" --event workflow_dispatch \
      --limit 5 --json databaseId,createdAt \
      --jq "[.[] | select(.createdAt >= \"$started\")][0].databaseId // empty")"
    [ -n "$run_id" ] && break
    sleep 5
  done
  [ -n "${run_id:-}" ] || { log "The started build did not appear."; return 1; }
  log "Waiting for build $run_id (about 15 min)…"
  if gh run watch "$run_id" -R "$REPO" --exit-status --interval 30 >/dev/null; then
    fetch
  else
    log "Build $run_id failed: https://github.com/$REPO/actions/runs/$run_id"
    notify "Retrail iOS build failed" "https://github.com/$REPO/actions/runs/$run_id"
    return 1
  fi
}

install_timer() {
  mkdir -p "$UNIT_DIR"
  sed "s#@SCRIPT@#$SCRIPT#" "$(dirname "$SCRIPT")/systemd/$UNIT_NAME.service" \
    > "$UNIT_DIR/$UNIT_NAME.service"
  cp "$(dirname "$SCRIPT")/systemd/$UNIT_NAME.timer" "$UNIT_DIR/$UNIT_NAME.timer"
  systemctl --user daemon-reload
  systemctl --user enable --now "$UNIT_NAME.timer"
  log "Timer active — checks every 5 min. Log: journalctl --user -u $UNIT_NAME"
}

remove_timer() {
  systemctl --user disable --now "$UNIT_NAME.timer" 2>/dev/null || true
  rm -f "$UNIT_DIR/$UNIT_NAME.service" "$UNIT_DIR/$UNIT_NAME.timer"
  systemctl --user daemon-reload
  log "Timer removed."
}

case "${1:-}" in
  "") fetch ;;
  --trigger) trigger ;;
  --install-timer) install_timer ;;
  --remove-timer) remove_timer ;;
  *) sed -n '2,14p' "$SCRIPT"; exit 2 ;;
esac
