# Retrail on an iPhone — without a Mac or a paid Apple account

The `iOS build` GitHub Actions workflow (`.github/workflows/ios-build.yml`) builds an
**unsigned** app on a macOS runner. A free Apple ID signs it on your Linux PC while
installing. Background: Spec 6 §G/§H.

## One-time setup

1. **Repository secrets** (GitHub → Settings → Secrets and variables → Actions):
   - `MAPTILER_KEY`: the key from your local `maptiler.json`
   - `IPA_PASSWORD`: a long random passphrase (`openssl rand -base64 24`). Keep it in your
     password manager, because GitHub never shows it again.
2. **Sideloader on Linux:** install [Splice](https://github.com/franklintra/splice). It
   needs `libimobiledevice` and, on Ubuntu, `sudo apt install libimobiledevice-utils usbmuxd`.
   You also need 7-Zip (`sudo apt install 7zip`).
3. **Apple ID:** `splice login`. The tool's authors recommend a secondary Apple ID over
   your main one.
4. **iPhone:** Settings → Privacy & Security → **Developer Mode** → on (the phone
   restarts). Connect it via USB and confirm "Trust this computer".

## Each new build

1. GitHub → **Actions** → **iOS build** → the latest green run → download the artifact
   `Retrail-ios-<n>`. It runs on every push to `main` / `phase/**`, or manually via
   "Run workflow".
2. Unpack: `unzip Retrail-ios-*.zip && 7z x Retrail.ipa.7z` (asks for `IPA_PASSWORD`).
3. Install: `splice install Retrail.ipa`.
4. The first time, trust your Apple ID on the iPhone: Settings → General → VPN & Device
   Management.

## Limits of the free signature

- **7 days:** after that the app no longer starts. Re-sign it with `splice refresh`, or let
  Splice's background service (`splice service`) do that automatically.
- **10 App IDs per 7 days:** the app and the Live Activity extension use 2 per install.
- Community tooling, not an Apple product. It can lag behind new iOS versions.

## What to test on the phone (Spec 6 device checklist)

- Start a ride → the Live Activity appears on the lock screen and in the Dynamic Island.
- The timer ticks with the phone locked. The distance updates while you move.
- Lock-screen **Pause** → "Ride paused", timer stops. **Resume** continues without counting
  the pause.
- Lock-screen **Stop** → the ride appears in the history, and the activity disappears.
- Tapping the activity opens the running ride.
- German phone language → German texts and a comma as decimal separator.
- Live Activities switched off (Settings → Retrail) → the ride still records.
- Force-quit the app during a ride and relaunch → no activity is left behind.
