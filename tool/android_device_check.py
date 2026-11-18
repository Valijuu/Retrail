#!/usr/bin/env python3
"""Checks the History map on a connected Android device (#96, #101, #110, #120).

    tool/android_device_check.py [--serial SERIAL] [--package ID] [--keep-going]

Drives the installed debug app (default `io.github.valijuu.retrail.debug`, German UI,
install it first: `flutter build apk --debug && adb install -r build/app/outputs/flutter-apk/app-debug.apk`)
through adb and uiautomator. It needs one device with at least one ride with a route in
the app, and the History tab on the map view is not required: the script opens it.

It saves no screenshot and no position, only reads the UI tree and the system's list of
location requests, and puts the device settings it changed (location services, Wi-Fi,
mobile data) back at the end. Prints PASS, FAIL or SKIP per check; exits 1 on a FAIL.
Checks that need a pixel or timing judgement (pin drag, theme switch race, empty history)
stay manual: see the list at the end of `docs/android-release.md`.
"""
import argparse
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

DEFAULT_PACKAGE = "io.github.valijuu.retrail.debug"

# German UI texts (lib/l10n/app_de.arb).
TAB_HISTORY = r"^\|Verlauf"
VIEW_MAP = r"\|Karte$"
BTN_MY_LOCATION = r"Mein Standort"
BTN_PLACE_SEARCH = r"Ort suchen"
BTN_CLOSE_SEARCH = r"Suche schließen"
BTN_FILTER = r"\|Filter$"
BTN_REMOVE_PIN = r"Pin entfernen"
HINT_SERVICES_OFF = r"Ortungsdienste sind aus"
HINT_LOST = r"Standort ist nicht mehr verfügbar"
HINT_SEARCH_DOWN = r"Ortssuche ist gerade nicht verfügbar"
SLIDER = r"Umkreis: 5 km"
SUGGESTION = r"Deutschland"

SETTLE_S = 1.5
HINT_WAIT_S = 8.0
OFFLINE_HINT_LIMIT_S = 5.0


class Device:
    """Thin adb wrapper for one device."""

    def __init__(self, serial: str | None):
        self.base = ["adb"] + (["-s", serial] if serial else [])

    def run(self, *args: str, check: bool = True) -> str:
        out = subprocess.run(
            self.base + list(args), capture_output=True, text=True, check=False
        )
        if check and out.returncode != 0:
            raise RuntimeError(f"adb {' '.join(args)} failed: {out.stderr.strip()}")
        return out.stdout

    def shell(self, command: str) -> str:
        return self.run("shell", command, check=False)

    def tree(self) -> ET.Element:
        """The current UI tree. A dump can fail while Flutter animates and then
        leaves the old file behind, so remove it first and retry."""
        for _ in range(4):
            self.shell("rm -f /sdcard/retrail_ui.xml")
            self.shell("uiautomator dump /sdcard/retrail_ui.xml")
            xml = self.run("exec-out", "cat", "/sdcard/retrail_ui.xml", check=False)
            if xml.strip().startswith("<?xml"):
                return ET.fromstring(xml)
            time.sleep(0.4)
        raise RuntimeError("uiautomator dump failed four times")

    def labelled(self):
        """(text, centre, class) of every node that has a text or a description."""
        for node in self.tree().iter("node"):
            text = (node.get("text") or "") + "|" + (node.get("content-desc") or "")
            if text == "|":
                continue
            x1, y1, x2, y2 = map(int, re.findall(r"\d+", node.get("bounds")))
            yield text, ((x1 + x2) // 2, (y1 + y2) // 2), node.get("class") or ""

    def has(self, pattern: str) -> bool:
        return any(re.search(pattern, text) for text, _, _ in self.labelled())

    def wait_for(self, pattern: str, seconds: float) -> float | None:
        """Seconds until a node matches, or None."""
        start = time.monotonic()
        while time.monotonic() - start < seconds:
            if self.has(pattern):
                return time.monotonic() - start
        return None

    def tap(self, pattern: str) -> None:
        for text, (x, y), _ in self.labelled():
            if re.search(pattern, text):
                self.shell(f"input tap {x} {y}")
                return
        raise LookupError(f"no element matches {pattern!r}")

    def active_location_requests(self, package: str) -> int:
        out = self.shell("dumpsys location")
        return len(
            re.findall(rf"^\s+service: ProviderRequest.*{re.escape(package)}", out, re.M)
        )

    def band_pixels(self) -> list[tuple[int, int, int]]:
        """Colours at three points of the band where the app's snack bars float.
        A snack bar without an action is not in the accessibility tree, so its
        presence is read from the screen: the raw frame is compared in memory and
        never saved."""
        raw = subprocess.run(
            self.base + ["exec-out", "screencap"], capture_output=True
        ).stdout
        width = int.from_bytes(raw[0:4], "little")
        height = int.from_bytes(raw[4:8], "little")
        header = len(raw) - width * height * 4
        y = int(height * 0.77)
        points = []
        for share in (0.04, 0.06, 0.82):  # margin, margin, gap before the close icon
            offset = header + (y * width + int(width * share)) * 4
            points.append(tuple(raw[offset : offset + 3]))
        return points

    def wait_for_band_change(self, baseline, seconds: float) -> bool:
        """Whether the snack bar band takes one colour that is not the baseline."""
        start = time.monotonic()
        while time.monotonic() - start < seconds:
            now = self.band_pixels()
            same = all(
                sum(abs(a - b) for a, b in zip(now[0], other)) < 12 for other in now[1:]
            )
            moved = sum(abs(a - b) for a, b in zip(now[1], baseline[1])) > 60
            if same and moved:
                return True
        return False

    def wait_online(self, seconds: float = 25) -> None:
        start = time.monotonic()
        while time.monotonic() - start < seconds:
            if "1 received" in self.shell("ping -c 1 -W 1 1.1.1.1"):
                break
            time.sleep(1)
        time.sleep(4)  # the app's connectivity stream follows the system

    def tap_at(self, x_share: float, y_share: float) -> None:
        """Taps a point given as a share of the screen, so it is not tied to one
        phone: the snackbar action (0.68, 0.77) and the search field (0.42, 0.22)."""
        size = re.search(r"(\d+)x(\d+)", self.shell("wm size"))
        width, height = int(size.group(1)), int(size.group(2))
        self.shell(f"input tap {int(width * x_share)} {int(height * y_share)}")

    def focus(self) -> str:
        return self.shell("dumpsys window | grep mCurrentFocus")


class Report:
    def __init__(self):
        self.rows: list[tuple[str, str, str]] = []

    def add(self, status: str, name: str, detail: str = "") -> None:
        self.rows.append((status, name, detail))
        print(f"{status:5} {name}" + (f" - {detail}" if detail else ""), flush=True)

    @property
    def failed(self) -> bool:
        return any(status == "FAIL" for status, _, _ in self.rows)


def settings_snapshot(dev: Device) -> dict[str, str]:
    return {
        "location_mode": dev.shell("settings get secure location_mode").strip(),
        "wifi_on": dev.shell("settings get global wifi_on").strip(),
        "mobile_data": dev.shell("settings get global mobile_data").strip(),
    }


def restore(dev: Device, before: dict[str, str]) -> None:
    dev.shell(
        "cmd location set-location-enabled "
        + ("true" if before["location_mode"] not in ("0", "null", "") else "false")
    )
    dev.shell("svc wifi " + ("enable" if before["wifi_on"] != "0" else "disable"))
    dev.shell("svc data " + ("enable" if before["mobile_data"] != "0" else "disable"))


def open_map(dev: Device, package: str) -> None:
    dev.shell(f"monkey -p {package} -c android.intent.category.LAUNCHER 1")
    # A cold start takes a while: wait for the tab bar instead of a fixed pause.
    if dev.wait_for(TAB_HISTORY, 30) is None:
        raise RuntimeError("the app did not show its tab bar within 30 s")
    dev.tap(TAB_HISTORY)
    time.sleep(SETTLE_S)
    if dev.has(VIEW_MAP):
        dev.tap(VIEW_MAP)
        time.sleep(SETTLE_S)
    if dev.wait_for(BTN_MY_LOCATION, 10) is None:
        raise RuntimeError(
            "the map view is not showing: the history needs a ride with a route"
        )


def check_services_off_hint(dev: Device, report: Report) -> None:
    name = "services off: hint with a way to the location settings (#120)"
    dev.shell("cmd location set-location-enabled false")
    time.sleep(1)
    baseline = dev.band_pixels()
    dev.tap(BTN_MY_LOCATION)
    if not dev.wait_for_band_change(baseline, HINT_WAIT_S):
        report.add("FAIL", name, "no snack bar appeared")
        return
    dev.tap_at(0.68, 0.77)  # the snackbar action, right of its text
    time.sleep(2)
    if "LocationSettings" in dev.focus():
        report.add("PASS", name)
    else:
        report.add("FAIL", name, "the action did not open the location settings")
    dev.run("shell", "input", "keyevent", "KEYCODE_BACK", check=False)
    time.sleep(1)


def check_slider_and_pin(dev: Device, report: Report) -> bool:
    name = "my location sets the pin; the slider reads its value in km (#120)"
    dev.shell("cmd location set-location-enabled true")
    time.sleep(1)
    dev.tap(BTN_MY_LOCATION)
    if dev.wait_for(SLIDER, 12) is None:
        report.add("FAIL", name, f"no element {SLIDER!r} (location fix may be missing)")
        return False
    report.add("PASS", name)
    return True


def check_pause_under_sheet(dev: Device, report: Report, package: str) -> None:
    name = "a sheet over the map pauses the position stream (#101)"
    running = dev.active_location_requests(package)
    if running != 1:
        report.add("SKIP", name, f"stream not running ({running} requests)")
        return
    dev.tap(BTN_FILTER)
    time.sleep(2)
    covered = dev.active_location_requests(package)
    dev.run("shell", "input", "keyevent", "KEYCODE_BACK", check=False)
    time.sleep(2)
    back = dev.active_location_requests(package)
    if (covered, back) == (0, 1):
        report.add("PASS", name)
    else:
        report.add("FAIL", name, f"requests covered={covered} back={back}, want 0 and 1")


def check_stream_lost(dev: Device, report: Report, package: str) -> None:
    """The system only sometimes reports a stream error when the services are
    switched off (it depends on the provider and the OS version), so a missing hint
    is a SKIP, not a FAIL: the logic is covered by `test/history_map`."""
    name = "services off while the position shows: the stream error shows a hint (#110)"
    for attempt in range(2):
        dev.shell("cmd location set-location-enabled true")
        time.sleep(1)
        dev.tap(BTN_MY_LOCATION)
        # The stream starts once the first fix is in, which can take a while.
        start = time.monotonic()
        while dev.active_location_requests(package) != 1:
            if time.monotonic() - start > 40:
                report.add("SKIP", name, "no location fix within 40 s (indoors?)")
                return
            time.sleep(1)
        time.sleep(6)  # an earlier hint is gone by now (they last 4 s)
        baseline = dev.band_pixels()
        dev.shell("cmd location set-location-enabled false")
        seen = dev.wait_for_band_change(baseline, HINT_WAIT_S)
        dev.shell("cmd location set-location-enabled true")
        if seen:
            report.add("PASS", name)
            return
    report.add("SKIP", name, "the system sent no stream error on this device")


def check_offline_search(dev: Device, report: Report) -> None:
    name = f"place search offline answers within {OFFLINE_HINT_LIMIT_S:.0f} s (#120)"
    dev.tap(BTN_PLACE_SEARCH)
    time.sleep(SETTLE_S)
    dev.shell("svc wifi disable")
    dev.shell("svc data disable")
    time.sleep(3)
    dev.tap_at(0.42, 0.22)  # the search field
    time.sleep(0.8)
    start = time.monotonic()
    dev.shell("input text Hamburg")
    seen = dev.wait_for(HINT_SEARCH_DOWN, 12)
    elapsed = time.monotonic() - start
    if seen is None:
        report.add("FAIL", name, "no hint")
    elif elapsed > OFFLINE_HINT_LIMIT_S:
        report.add("FAIL", name, f"{elapsed:.1f} s")
    else:
        report.add("PASS", name, f"{elapsed:.1f} s including typing")
    dev.shell("svc wifi enable")
    dev.shell("svc data enable")
    dev.wait_online()


def check_type_back(dev: Device, report: Report) -> None:
    """Runs right after the offline check: the field still holds "Hamburg" and the
    network is back, so one more character sends the text again."""
    name = "typing a character and deleting it keeps the suggestions (#125)"
    for _ in range(2):
        dev.shell("input text x")
        dev.shell("input keyevent KEYCODE_DEL")
        if dev.wait_for(SUGGESTION, 12) is not None:
            break
    else:
        report.add("SKIP", name, "no suggestions (offline?)")
        return
    dev.shell("input text x")
    dev.shell("input keyevent KEYCODE_DEL")
    time.sleep(2.5)
    if dev.has(SUGGESTION):
        report.add("PASS", name)
    else:
        report.add("FAIL", name, "the suggestions did not come back")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--serial")
    parser.add_argument("--package", default=DEFAULT_PACKAGE)
    args = parser.parse_args()

    dev = Device(args.serial)
    devices = [
        line.split()[0]
        for line in dev.run("devices").splitlines()[1:]
        if line.strip().endswith("device")
    ]
    if not devices:
        print("no device: connect one and allow USB debugging", file=sys.stderr)
        return 2
    if len(devices) > 1 and not args.serial:
        print(f"several devices {devices}: pass --serial", file=sys.stderr)
        return 2
    if args.package not in dev.shell("pm list packages"):
        print(f"{args.package} is not installed", file=sys.stderr)
        return 2

    before = settings_snapshot(dev)
    report = Report()
    try:
        for permission in ("ACCESS_FINE_LOCATION", "ACCESS_COARSE_LOCATION"):
            dev.shell(f"pm grant {args.package} android.permission.{permission}")
        open_map(dev, args.package)
        check_services_off_hint(dev, report)
        if check_slider_and_pin(dev, report):
            check_pause_under_sheet(dev, report, args.package)
        check_stream_lost(dev, report, args.package)
        check_offline_search(dev, report)
        check_type_back(dev, report)
    except (RuntimeError, LookupError) as error:
        report.add("FAIL", "the run", str(error))
    finally:
        restore(dev, before)
        dev.shell("rm -f /sdcard/retrail_ui.xml")
    print(f"{len(report.rows)} checks, {'FAILED' if report.failed else 'ok'}")
    return 1 if report.failed else 0


if __name__ == "__main__":
    sys.exit(main())
