#!/usr/bin/env bash
# Takes App Store screenshots in the iOS Simulator (macOS only; runs on the
# GitHub runner, see .github/workflows/ios-screenshots.yml and docs/app-store.md).
#
#   tool/ios_screenshots.sh <lang: en|de> <theme: light|dark> <out_dir>
#
# Expects build/ios/iphonesimulator/Runner.app (flutter build ios --simulator
# --debug) and build/demo_rides/retrail_<lang>.sqlite (tool/demo_rides, invented
# routes on Tempelhofer Feld). Writes <out_dir>/<lang>_<theme>_NN_<screen>.png at
# 1320 x 2868 px (6.9" iPhone), the size App Store Connect requires: the home
# screen from a plain launch, the other motives through
# integration_test/store_screenshots_test.dart (all in light, the ride in dark).
set -euo pipefail

LANG_CODE="${1:?language en|de}"
THEME="${2:?theme light|dark}"
OUT_DIR="${3:?output directory}"
case "${LANG_CODE}" in en|de) ;; *) echo "language must be en or de" >&2; exit 1 ;; esac
case "${THEME}" in light|dark) ;; *) echo "theme must be light or dark" >&2; exit 1 ;; esac

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

# Seed with the simulator shut down: then no cfprefsd (neither the simulator's
# nor the Mac's) holds the app's defaults in memory, and the next boot reads the
# file. `defaults write` does not work here: `simctl spawn defaults` writes the
# simulator's own domain, not the app container (run 41615367688), and the
# host's `defaults write <path>` only reached the Mac's cfprefsd cache, the file
# was never written (runs 41622554499, 41625884885). shared_preferences on iOS
# reads NSUserDefaults with the "flutter." key prefix.
xcrun simctl shutdown "${UDID}"
PREFS="${DATA}/Library/Preferences/${BUNDLE}.plist"
mkdir -p "${DATA}/Library/Preferences"
cat > "${PREFS}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>flutter.user_name</key><string>Retrailer</string>
  <key>flutter.onboarding_done</key><true/>
  <key>flutter.app_language</key><string>${LANG_CODE}</string>
  <key>flutter.theme_mode</key><string>${THEME}</string>
  <key>flutter.battery_hint_dismissed</key><true/>
</dict>
</plist>
PLIST
plutil -convert binary1 "${PREFS}"
plutil -p "${PREFS}" # shows in the workflow log: what the app will read
plutil -p "${PREFS}" | grep -qF '"flutter.onboarding_done" => true' \
  || { echo "prefs not seeded: ${PREFS}" >&2; exit 1; }

# The app opens its Drift database in the documents directory
# (lib/data/db/database_connection.dart).
mkdir -p "${DATA}/Documents"
rm -f "${DATA}/Documents/retrail.sqlite"{,-wal,-shm}
cp "${DEMO_DB}" "${DATA}/Documents/retrail.sqlite"

xcrun simctl boot "${UDID}"
xcrun simctl bootstatus "${UDID}" -b
prepare_sim

mkdir -p "${OUT_DIR}"
shot() { # <name>: screenshot of whatever is on screen now
  local file="${OUT_DIR}/${LANG_CODE}_${THEME}_$1.png"
  xcrun simctl io "${UDID}" screenshot --type=png "${file}"
  local w h
  w="$(sips -g pixelWidth "${file}" | awk '/pixelWidth/ {print $2}')"
  h="$(sips -g pixelHeight "${file}" | awk '/pixelHeight/ {print $2}')"
  if [ "${w}" != "${WIDTH}" ] || [ "${h}" != "${HEIGHT}" ]; then
    echo "${file} is ${w}x${h}, App Store Connect needs ${WIDTH}x${HEIGHT}" >&2
    return 1
  fi
}

# A green run must mean the right content, not only the right size: read the
# text in the shot and fail on onboarding, the wrong language or no rides.
SCREEN_TEXT="build/ios_screen_text"
test -x "${SCREEN_TEXT}" || swiftc -O -o "${SCREEN_TEXT}" tool/ios_screen_text.swift
expect_home() { # <name>
  local file="${OUT_DIR}/${LANG_CODE}_${THEME}_$1.png" text want empty
  text="$("${SCREEN_TEXT}" "${file}")"
  echo "--- text in ${file}:"; echo "${text}"; echo "---"
  if [ "${LANG_CODE}" = de ]; then want="Tracking starten"; empty="Noch keine Fahrten"
  else want="Start tracking"; empty="No rides yet"; fi
  grep -qiF "${want}" <<<"${text}" || { echo "${file}: no \"${want}\", not the ${LANG_CODE} home screen" >&2; return 1; }
  if grep -qiF "${empty}" <<<"${text}"; then echo "${file}: no demo rides" >&2; return 1; fi
}

xcrun simctl launch "${UDID}" "${BUNDLE}" >/dev/null
sleep 10 # map tiles come from OpenFreeMap over the network
# A failed shot is collected in FAILED, not fatal: the other motives still run,
# and the script fails at the end.
FAILED=""
if shot "01_home"; then expect_home "01_home" || FAILED="${FAILED} 01_home(text)"
else FAILED="${FAILED} 01_home(size)"; fi

xcrun simctl terminate "${UDID}" "${BUNDLE}" 2>/dev/null || true

# The other motives: integration_test/store_screenshots_test.dart drives the
# app (taps, routes, replayed demo GPS) and prints "RETRAIL_SHOT <name>"; this
# loop takes the shot and answers with an ack file in the app's Documents,
# because the simulator cannot tap from the command line and the test's own
# screenshot misses the map (a native view). The dark set needs only the ride
# (05_dark); the countdown has its own dark palette in either theme.
if [ "${THEME}" = light ]; then
  SHOTS="02_history,03_detail,04_best_time,05_follow,06_countdown,07_track,08_activities"
else
  SHOTS="07_track"
fi

# Text that must be in a motive's shot: the screen and the shot's language.
expected_text() { # <name>
  case "$1:${LANG_CODE}" in
    02_history:en) echo "Followed" ;;
    02_history:de) echo "Nachgefahren" ;;
    03_detail:en) echo "Avg speed" ;;
    03_detail:de) echo "Geschwindigkeit" ;;
    04_best_time:en) printf '%s\n' "Original" "Followed (" ;;
    04_best_time:de) printf '%s\n' "Original" "Nachgefahren (" ;;
    05_follow:en) echo "to go" ;;
    05_follow:de) echo "noch " ;;
    06_countdown:en) echo "GET READY" ;;
    06_countdown:de) echo "FERTIG MACHEN" ;;
    07_track:en) printf '%s\n' "Distance" "Pause" ;;
    07_track:de) printf '%s\n' "Strecke" "Pause" ;;
    08_activities:en) echo "How do you roll" ;;
    08_activities:de) echo "Wie fährst du" ;;
  esac
}
check_text() { # <name>: fails when an expected text is not in the shot
  local file="${OUT_DIR}/${LANG_CODE}_${THEME}_$1.png" text want ok=0
  text="$("${SCREEN_TEXT}" "${file}")"
  echo "--- text in ${file}:"; echo "${text}"; echo "---"
  while IFS= read -r want; do
    [ -z "${want}" ] && continue
    grep -qiF "${want}" <<<"${text}" || { echo "${file}: no \"${want}\"" >&2; ok=1; }
  done <<<"$(expected_text "$1")"
  return "${ok}"
}
app_data() { # the app's data container; fails when the app is not installed
  xcrun simctl get_app_container "${UDID}" "${BUNDLE}" data 2>/dev/null \
    || { echo "app ${BUNDLE} is not installed any more: the test ended (or the app died) before this step" >&2; return 1; }
}
ack() { # <name>: tells the test the shot is taken
  local data
  data="$(app_data)" || return 1
  mkdir -p "${data}/Documents/shot_ack"
  touch "${data}/Documents/shot_ack/$1"
}

# The loop must answer fast: the test waits for each ack, and the simulator
# host is slow while the map renders (an OCR pass took 2 min in run
# 41634306589, the test gave up and the next shot caught the home screen
# after the app was uninstalled). So the text checks run after the test.
TAKEN=","
TEST_STATUS=1
while IFS= read -r line; do
  printf '%s\n' "${line}"
  case "${line}" in
    *RETRAIL_SETUP*)
      # The test build is installed now: give it the demo rides.
      if data="$(app_data </dev/null)"; then
        rm -rf "${data}/Documents/shot_ack"
        mkdir -p "${data}/Documents"
        cp "${DEMO_DB}" "${data}/Documents/store_demo.sqlite"
        ack setup </dev/null || true
      else
        FAILED="${FAILED} setup"
      fi
      ;;
    *"RETRAIL_SHOT "*)
      name="$(sed -E 's/.*RETRAIL_SHOT ([A-Za-z0-9_]+).*/\1/' <<<"${line}")"
      case "${TAKEN}" in *",${name},"*) continue ;; esac # a repeated log line
      TAKEN="${TAKEN}${name},"
      # </dev/null: nothing in here may eat the test output this loop reads.
      # The app must still be there, else the shot shows the home screen.
      if app_data </dev/null >/dev/null; then
        shot "${name}" </dev/null || FAILED="${FAILED} ${name}(size)"
        ack "${name}" </dev/null || FAILED="${FAILED} ${name}(ack)"
      else
        FAILED="${FAILED} ${name}(app gone)"
      fi
      ;;
    *RETRAIL_NO_ACK*) FAILED="${FAILED} ${line##*RETRAIL_NO_ACK }(no ack, shot may be late)" ;;
    RETRAIL_EXIT*) TEST_STATUS="${line#RETRAIL_EXIT }" ;;
  esac
done < <(
  flutter test integration_test/store_screenshots_test.dart -d "${UDID}" \
    --reporter expanded \
    --dart-define=RETRAIL_SHOT_LANG="${LANG_CODE}" \
    --dart-define=RETRAIL_SHOT_THEME="${THEME}" \
    --dart-define=RETRAIL_SHOTS="${SHOTS}" 2>&1
  echo "RETRAIL_EXIT $?"
)

for name in ${SHOTS//,/ }; do
  if [ ! -f "${OUT_DIR}/${LANG_CODE}_${THEME}_${name}.png" ]; then
    FAILED="${FAILED} ${name}(missing)"
  elif [ "${TAKEN}" != "${TAKEN/,${name},/}" ]; then
    check_text "${name}" || FAILED="${FAILED} ${name}(text)"
  fi
done
[ "${TEST_STATUS}" = 0 ] || echo "warning: the screenshot test exited with ${TEST_STATUS}" >&2
if [ -n "${FAILED}" ]; then
  echo "${LANG_CODE} ${THEME}: failed shots:${FAILED}" >&2
  exit 1
fi
