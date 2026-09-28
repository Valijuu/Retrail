#!/usr/bin/env bash
# Downloads the newest green iOS build (GitHub Actions "iOS build" on main) to
# ~/Downloads/retrail-ios/Retrail.ipa.7z, replacing the previous one, and — if an
# iPhone is connected via USB — unpacks and installs it with Splice. Desktop
# notifications report each step. Does nothing that was already done.
#
#   tool/ios_fetch_build.sh            fetch the latest green build (if new), install it
#   tool/ios_fetch_build.sh --wait     wait for the build running on main (started by a
#                                      push or "Run workflow" on GitHub), fetch, install
#   tool/ios_fetch_build.sh --trigger  start a new build on main, wait, fetch, install
#   tool/ios_fetch_build.sh --install  only install the already downloaded build
#   tool/ios_fetch_build.sh --store-password
#                                      save IPA_PASSWORD in the login keyring (once)
#
# RETRAIL_IOS_BRANCH=<branch> builds/fetches that branch instead of main — to try
# Swift changes on a device before they reach main.
#
# Installing needs: the iPhone on USB (unlocked, this PC trusted), the password in
# the keyring (`--store-password`, needs `secret-tool` from libsecret-tools), and a
# Splice login — see docs/ios-sideloading.md.
set -euo pipefail

REPO="Valijuu/Retrail"
WORKFLOW="ios-build.yml"
BRANCH="${RETRAIL_IOS_BRANCH:-main}"
DEST="${RETRAIL_IOS_DIR:-$HOME/Downloads/retrail-ios}"
STATE="$DEST/.artifact-id"
SCRIPT="$(readlink -f "$0")"
INSTALLED_STATE="$DEST/.installed-id"

# Splice lives in ~/.local/bin, which a git hook's PATH may lack.
SPLICE="$(command -v splice || echo "$HOME/.local/bin/splice")"
# Apple's root CA for gsa.apple.com (see docs/ios-sideloading.md, Troubleshooting).
SPLICE_CA_BUNDLE="$HOME/.config/splice/ca-with-apple.crt"
ANISETTE_CONTAINER="anisette-v3"
KEYRING_ATTRS=(service retrail-ios key ipa-password)

# A build takes a few seconds to show up after a push / "Run workflow".
APPEAR_TIMEOUT_S=60
APPEAR_POLL_S=5
# How long to wait for the 2FA login in the terminal window.
LOGIN_TIMEOUT_S=600
# While waiting for a build, a gh call can fail on a network blip (Wi-Fi drop,
# connection reset) — that is not the build failing (#39). Retry this often,
# this far apart, before giving up on reaching GitHub.
GH_RETRIES=20
GH_RETRY_S=30

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
    install_build
    return
  fi

  local tmp; tmp="$(mktemp -d)"
  if ! gh api "repos/$REPO/actions/artifacts/$artifact/zip" > "$tmp/artifact.zip" ||
     ! unzip -q -o "$tmp/artifact.zip" -d "$tmp" ||
     [ ! -f "$tmp/Retrail.ipa.7z" ]; then
    rm -rf "$tmp"
    log "Downloading build #$run_no failed."
    return 1
  fi

  # Replace the old build: the encrypted archive and anything unpacked from it.
  rm -rf "$DEST/Retrail.ipa" "$DEST/dist"
  mv -f "$tmp/Retrail.ipa.7z" "$DEST/Retrail.ipa.7z"
  rm -rf "$tmp"
  printf '%s\n' "$artifact" > "$STATE"

  log "Build #$run_no ($title) → $DEST/Retrail.ipa.7z"
  notify "Retrail iOS build #$run_no ready" "$title — $DEST/Retrail.ipa.7z"
  install_build
}

# USB only (`-l`): installing over Wi-Fi is slower and flakier.
iphone_connected() { [ -n "$(idevice_id -l 2>/dev/null)" ]; }

# Empty when secret-tool is missing or nothing is stored (never fails: set -e).
ipa_password() {
  command -v secret-tool >/dev/null 2>&1 || return 0
  secret-tool lookup "${KEYRING_ATTRS[@]}" 2>/dev/null || true
}

# Splice's local anisette server must run, or the Apple login fails / loops.
ensure_anisette() {
  command -v docker >/dev/null 2>&1 || return 0
  if [ "$(docker inspect -f '{{.State.Running}}' "$ANISETTE_CONTAINER" 2>/dev/null)" = "false" ]; then
    log "Starting $ANISETTE_CONTAINER…"
    docker start "$ANISETTE_CONTAINER" >/dev/null && sleep 3
  fi
}

# Unpacks the downloaded build and installs it with Splice — only if an iPhone is
# on USB and this build isn't installed yet. Never touches the phone otherwise.
install_build() {
  local artifact work password
  artifact="$(cat "$STATE" 2>/dev/null)"
  if [ ! -f "$DEST/Retrail.ipa.7z" ] || [ -z "$artifact" ]; then
    log "No downloaded build to install."
    return 0
  fi
  if [ "$(cat "$INSTALLED_STATE" 2>/dev/null)" = "$artifact" ]; then
    log "This build is already installed."
    return 0
  fi
  if ! command -v idevice_id >/dev/null 2>&1 || ! iphone_connected; then
    log "No iPhone on USB — not installing."
    notify "Retrail: iPhone not connected" \
      "Connect it via USB, then run tool/ios_fetch_build.sh --install"
    return 0
  fi
  password="$(ipa_password)"
  if [ -z "$password" ]; then
    log "No IPA password in the keyring — run: tool/ios_fetch_build.sh --store-password"
    notify "Retrail: install skipped" "No IPA password in the keyring (--store-password)"
    return 1
  fi
  if [ ! -x "$SPLICE" ]; then
    log "Splice not found at $SPLICE."
    notify "Retrail: install skipped" "Splice is not installed"
    return 1
  fi

  work="$(mktemp -d)"
  if unpack_and_install "$password" "$work"; then
    rm -rf "$work"
    printf '%s\n' "$artifact" > "$INSTALLED_STATE"
    log "Installed."
    notify "Retrail installed" "The new build is on the iPhone."
  else
    rm -rf "$work"
    return 1
  fi
}

# Unpacks into [work] and runs Splice. The unpacked (unencrypted) .ipa only ever
# lives in that temp dir, which the caller removes.
unpack_and_install() {
  local password="$1" work="$2"
  log "Unpacking…"
  if ! 7z x -p"$password" -y -o"$work" "$DEST/Retrail.ipa.7z" >/dev/null; then
    log "Unpacking failed (wrong IPA password?)."
    notify "Retrail: install failed" "Could not unpack Retrail.ipa.7z (wrong password?)"
    return 1
  fi
  ensure_anisette
  local splice_ok=true
  splice_install "$work" || splice_ok=false
  # An expired Apple session needs a 2FA code, which this unattended run can't
  # read: log in in a terminal window, then try once more.
  if ! $splice_ok && grep -qiE 'session has expired|log in|2FA' "$work/splice.out" &&
     login_in_terminal "$work"; then
    splice_ok=true
    splice_install "$work" || splice_ok=false
  fi
  if ! $splice_ok; then
    log "Splice failed — is the iPhone unlocked and still logged in (splice login)?"
    notify "Retrail: install failed" "Unlock the iPhone and run tool/ios_fetch_build.sh --install"
    return 1
  fi
}

splice_install() {
  local work="$1"
  log "Installing on the iPhone (keep it unlocked)…"
  local rc=0
  SSL_CERT_FILE="$SPLICE_CA_BUNDLE" "$SPLICE" install "$work/Retrail.ipa" \
    </dev/null >"$work/splice.out" 2>&1 || rc=$?
  summarize_splice_output "$work/splice.out"
  return "$rc"
}

# Runs `splice login` in a new terminal window so the 2FA code sent to the
# iPhone can be typed in, and waits until it's done. The terminal doesn't block,
# so the window reports its exit code through a file.
login_in_terminal() {
  local work="$1" status="$1/login.status" waited=0
  if [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] || ! command -v x-terminal-emulator >/dev/null 2>&1; then
    log "Apple login expired — run: splice login, then tool/ios_fetch_build.sh --install"
    return 1
  fi
  log "Apple login expired — opening a terminal for splice login (enter the code there)…"
  notify "Retrail: Apple login needed" "Enter the code from your iPhone in the terminal window"
  x-terminal-emulator -- bash -c '
    echo "Retrail: Apple login for Splice. Enter the 2FA code from your iPhone."
    echo
    SSL_CERT_FILE="$1" "$2" login; rc=$?
    echo "$rc" > "$3"
    if [ "$rc" -ne 0 ]; then read -rp "Login failed — press Enter to close."; fi
  ' _ "$SPLICE_CA_BUNDLE" "$SPLICE" "$status" >/dev/null 2>&1 &
  while [ ! -s "$status" ] && [ "$waited" -lt "$LOGIN_TIMEOUT_S" ]; do
    sleep 2; waited=$((waited + 2))
  done
  if [ "$(cat "$status" 2>/dev/null)" != "0" ]; then
    log "Splice login did not complete."
    return 1
  fi
  log "Logged in — retrying the install."
}

# Splice redraws a progress bar in place (hundreds of "|###  | 88/100" frames).
# Log each step once instead: strip ANSI codes and bars, drop repeats.
summarize_splice_output() {
  sed -E -e 's/\x1b\[[0-9;?]*[A-Za-z]/\n/g' -e 's/\r/\n/g' -e 's/·/\n·/g' "$1" \
    | sed -E -e 's/ *\|[# ]*\| *[0-9]+\/100//' -e 's/^[[:space:]]+|[[:space:]]+$//g' \
    | awk 'NF && !seen[$0]++ { print "  splice: " $0 }'
}

store_password() {
  command -v secret-tool >/dev/null 2>&1 \
    || { log "secret-tool missing: sudo apt install libsecret-tools"; return 1; }
  secret-tool store --label="Retrail IPA_PASSWORD" "${KEYRING_ATTRS[@]}"
  log "Stored. The next build installs automatically when an iPhone is on USB."
}

# Prints "<status> <conclusion>" of run [run_id] (e.g. "completed success"),
# retrying gh on errors. Fails only when GitHub stayed unreachable throughout.
run_state() {
  local run_id="$1" state
  for _ in $(seq 1 "$GH_RETRIES"); do
    if state="$(gh run view "$run_id" -R "$REPO" --json status,conclusion \
        --jq '"\(.status) \(.conclusion)"')"; then
      printf '%s' "$state"
      return 0
    fi
    log "GitHub not reachable — retrying in ${GH_RETRY_S}s…" >&2
    sleep "$GH_RETRY_S"
  done
  return 1
}

# Waits for run [run_id] to finish; fetches it when green. `gh run watch` also
# exits non-zero when its connection drops, so its exit code alone never decides
# "failed" — the run's own conclusion does (#39).
watch_and_fetch() {
  local run_id="$1" state
  log "Waiting for build $run_id (about 15 min)…"
  while :; do
    gh run watch "$run_id" -R "$REPO" --interval 30 >/dev/null 2>&1 || true
    if ! state="$(run_state "$run_id")"; then
      log "Lost contact with GitHub — build $run_id: https://github.com/$REPO/actions/runs/$run_id"
      notify "Retrail: GitHub not reachable" \
        "Run tool/ios_fetch_build.sh once build $run_id is done"
      return 1
    fi
    case "$state" in
      "completed success") fetch; return ;;
      completed\ *) break ;;
    esac
    # Still queued / running: the watch only dropped out — keep waiting.
    sleep "$GH_RETRY_S"
  done
  log "Build $run_id failed (${state#completed }): https://github.com/$REPO/actions/runs/$run_id"
  notify "Retrail iOS build failed" "https://github.com/$REPO/actions/runs/$run_id"
  return 1
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
  --install) install_build ;;
  --store-password) store_password ;;
  *) sed -n '2,19p' "$SCRIPT"; exit 2 ;;
esac
