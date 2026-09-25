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
3. **Apple ID:** `splice login` (in a real terminal; it prompts for Apple ID, password and
   the 2FA code). The tool's authors recommend a secondary Apple ID, but see
   "Troubleshooting": right now it has to be an ID with a **trusted device**.
   Before logging in on Ubuntu, apply the two fixes under "Troubleshooting".
4. **iPhone:** Settings → Privacy & Security → **Developer Mode** → on (the phone
   restarts). Connect it via USB and confirm "Trust this computer".

## Each new build

1. GitHub → **Actions** → **iOS build** → the latest green run → download the artifact
   `Retrail-ios-<n>`. It runs on every push to `main` / `phase/**` that changes app code
   (`lib/`, `ios/`, `assets/`, `pubspec.*`), or manually via "Run workflow".
2. Unpack: `unzip Retrail-ios-*.zip && 7z x Retrail.ipa.7z` (asks for `IPA_PASSWORD`).
3. Install: `splice install Retrail.ipa`.
4. The first time, trust your Apple ID on the iPhone: Settings → General → VPN & Device
   Management.

## Limits of the free signature

- **7 days:** after that the app no longer starts. Re-sign it with `splice refresh`, or let
  Splice's background service (`splice service`) do that automatically.
- **10 App IDs per 7 days:** the app and the Live Activity extension use 2 per install.
- Community tooling, not an Apple product. It can lag behind new iOS versions.

## Troubleshooting Splice on Ubuntu (26.04, Splice v1.0.0)

- **`ssl connect failed: certificate verify failed`** (splice issue
  [#23](https://github.com/franklintra/splice/issues/23)): `gsa.apple.com` chains to
  Apple's private **Apple Root CA**, and Ubuntu's trust store doesn't include it. Give
  Splice a bundle that also contains Apple's root:
  ```bash
  mkdir -p ~/.config/splice
  curl -fsSL https://www.apple.com/appleca/AppleIncRootCertificate.cer \
    | openssl x509 -inform DER > /tmp/apple-root-ca.pem
  openssl x509 -in /tmp/apple-root-ca.pem -noout -fingerprint -sha256
  # must print B0:B1:73:0E:CB:C7:FF:45:05:14:2C:49:F1:29:5E:6E:DA:6B:CA:ED:7E:2C:68:C5:BE:91:B5:A1:10:01:F0:24
  cat /etc/ssl/certs/ca-certificates.crt /tmp/apple-root-ca.pem > ~/.config/splice/ca-with-apple.crt
  echo "alias splice='SSL_CERT_FILE=\$HOME/.config/splice/ca-with-apple.crt splice'" >> ~/.bashrc
  ```
  The background refresh service doesn't read the alias. If you want it, add the root
  system-wide instead: copy the `.pem` to `/usr/local/share/ca-certificates/apple-root-ca.crt`
  and run `sudo update-ca-certificates`.
- **Segfault right after "Sending first auth request"**: Apple answers `503` because it
  rejects Splice's locally emulated anisette data, and Splice crashes parsing the HTML.
  Use a remote anisette server once. Splice then remembers it:
  `splice --anisette-server https://ani.sidestore.io login`. The anisette server never
  sees your Apple ID or password.
- **Endless 2FA loop with an Apple ID that has no trusted device (SMS only)**: splice issue
  [#25](https://github.com/franklintra/splice/issues/25). The SMS code is accepted, then
  Splice asks again, forever. Until that is fixed, use an Apple ID that is signed in to
  iCloud on an Apple device (e.g. your iPhone). The code then arrives as a push on that
  device (or via Settings → your name → Sign-In & Security → Get Verification Code).
- **Seeing what happens:** `splice --log-level debug login`.

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
