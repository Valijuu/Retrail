#!/usr/bin/env bash
# Takes App Store screenshots in the iOS Simulator (macOS only; runs on the
# GitHub runner, see .github/workflows/ios-screenshots.yml and docs/app-store.md).
#
#   tool/ios_screenshots.sh <lang: en|de> <theme: light|dark> <out_dir>
#
# Expects build/ios/iphonesimulator/Runner.app (flutter build ios --simulator
# --debug) and build/demo_rides/retrail_<lang>.sqlite (tool/demo_rides, invented
# routes on Tempelhofer Feld). Writes <out_dir>/<lang>_<theme>_NN_<screen>.png at
# 1320 x 2868 px (6.9" iPhone), the size App Store Connect requires.
set -euo pipefail

LANG_CODE="${1:?language en|de}"
THEME="${2:?theme light|dark}"
OUT_DIR="${3:?output directory}"

BUNDLE="io.github.valijuu.retrail"
APP="build/ios/iphonesimulator/Runner.app"
DEMO_DB="build/demo_rides/retrail_${LANG_CODE}.sqlite"
WIDTH=1320
HEIGHT=2868
# Tempelhofer Feld, Berlin: where the demo rides are.
LAT=52.4732
LNG=13.4040

test -d "${APP}" || { echo "missing ${APP}: build the simulator app first" >&2; exit 1; }
test -f "${DEMO_DB}" || { echo "missing ${DEMO_DB}: build the demo database first" >&2; exit 1; }

# 6.9" iPhones: the Pro Max models of the last two generations.
UDID=""
for name in "iPhone 17 Pro Max" "iPhone 16 Pro Max"; do
  UDID="$(xcrun simctl list devices available | grep -m1 "    ${name} (" | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/' || true)"
  [ -n "${UDID}" ] && break
done
test -n "${UDID}" || { echo "no 6.9\" iPhone simulator available" >&2; exit 1; }

xcrun simctl boot "${UDID}" 2>/dev/null || true
xcrun simctl bootstatus "${UDID}" -b

# Same status bar as the Play shots: 9:41, full battery and signal. Status bar
# overrides do not survive a reboot, so this runs again after the one below.
prepare_sim() {
  xcrun simctl status_bar "${UDID}" override --time "9:41" --batteryState charged \
    --batteryLevel 100 --wifiBars 3 --cellularBars 4 --operatorName ""
  xcrun simctl ui "${UDID}" appearance "${THEME}"
  xcrun simctl location "${UDID}" set "${LAT},${LNG}"
}
prepare_sim

# Clean install, then one launch so iOS creates the data container.
xcrun simctl uninstall "${UDID}" "${BUNDLE}" 2>/dev/null || true
xcrun simctl install "${UDID}" "${APP}"
xcrun simctl privacy "${UDID}" grant location-always "${BUNDLE}"
xcrun simctl launch "${UDID}" "${BUNDLE}" >/dev/null
sleep 5
xcrun simctl terminate "${UDID}" "${BUNDLE}"


DATA="$(xcrun simctl get_app_container "${UDID}" "${BUNDLE}" data)"

# Seed: the shared_preferences keys carry the "flutter." prefix on iOS. They go
# straight into the app's container plist, with the app not running. A
# `simctl spawn defaults write` lands in the simulator's own domain instead, and
# the app then starts in onboarding (run 41615367688, English, no rides).
PREFS="${DATA}/Library/Preferences/${BUNDLE}"
mkdir -p "${DATA}/Library/Preferences"
defaults write "${PREFS}" flutter.user_name -string "Retrailer"
defaults write "${PREFS}" flutter.onboarding_done -bool true
defaults write "${PREFS}" flutter.app_language -string "${LANG_CODE}"
defaults write "${PREFS}" flutter.theme_mode -string "${THEME}"
defaults write "${PREFS}" flutter.battery_hint_dismissed -bool true
test "$(defaults read "${PREFS}" flutter.onboarding_done)" = 1 || { echo "prefs not seeded" >&2; exit 1; }
plutil -p "${PREFS}.plist" # shows in the workflow log: what the app will read

# cfprefsd keeps the values of the first launch in memory and can ignore the
# edited file; a reboot of the simulator makes it read the plist again.
xcrun simctl shutdown "${UDID}"
xcrun simctl boot "${UDID}"
xcrun simctl bootstatus "${UDID}" -b
prepare_sim
rm -f "${DATA}/Documents/retrail.sqlite"{,-wal,-shm}
cp "${DEMO_DB}" "${DATA}/Documents/retrail.sqlite"

mkdir -p "${OUT_DIR}"
shot() { # <name>: screenshot of whatever is on screen now
  local file="${OUT_DIR}/${LANG_CODE}_${THEME}_$1.png"
  xcrun simctl io "${UDID}" screenshot --type=png "${file}"
  local w h
  w="$(sips -g pixelWidth "${file}" | awk '/pixelWidth/ {print $2}')"
  h="$(sips -g pixelHeight "${file}" | awk '/pixelHeight/ {print $2}')"
  if [ "${w}" != "${WIDTH}" ] || [ "${h}" != "${HEIGHT}" ]; then
    echo "${file} is ${w}x${h}, App Store Connect needs ${WIDTH}x${HEIGHT}" >&2
    exit 1
  fi
}

xcrun simctl launch "${UDID}" "${BUNDLE}" >/dev/null
sleep 10 # map tiles come from OpenFreeMap over the network
shot "01_home"

# TODO (scaffold ends here): the simulator cannot tap from the command line. The
# other motives of store/play/screenshots.tsv (history, detail, comparison sheet,
# countdown, running ride) need either an integration_test that navigates and
# captures, or idb (Facebook's iOS debug bridge) for taps; the Live Activity shot
# needs a ride started in the app and the lock screen captured.
