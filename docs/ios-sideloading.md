# Retrail on an iPhone — without a Mac or a paid Apple account

The **iOS build** GitHub Actions workflow (`.github/workflows/ios-build.yml`) builds an
**unsigned** app on a macOS runner. `tool/ios_fetch_build.sh` downloads it to this Linux PC and
installs it on an iPhone connected via USB. [Splice](https://github.com/franklintra/splice)
signs it with a free Apple ID during the install. Background: Spec 6 §G/§H.

```
push app code to main ──► GitHub Actions: iOS build (~5–15 min, encrypted .ipa artifact)
        │ .githooks/pre-push starts tool/ios_fetch_build.sh --wait in the background
        ▼
~/Downloads/retrail-ios/Retrail.ipa.7z ──► iPhone on USB? ── no ──► notification "not connected"
                                                 │ yes
                                                 ▼
             unpack (password from keyring) ──► splice install ──► notification "installed"
```

---

## One-time setup

Do these steps in this order. Everything below was set up and verified on Ubuntu 26.04 with an
iPhone 8 on iOS 16.7.

### 1. GitHub

- **Repository secrets** (GitHub → Settings → Secrets and variables → Actions):
  - `MAPTILER_KEY`: the key from your local `maptiler.json`.
  - `IPA_PASSWORD`: a long random passphrase (`openssl rand -base64 24`). Keep it in your
    password manager, because GitHub never shows it again.
- The `gh` CLI must be logged in with the `workflow` scope:
  `gh auth refresh -h github.com -s workflow`.

### 2. Packages

```bash
sudo apt install usbmuxd libimobiledevice-utils 7zip libsecret-tools
```

Docker is needed as well, for the anisette server in step 5.

### 3. Splice (the sideloader)

```bash
mkdir -p ~/.local/bin
gh release download v1.0.0 -R franklintra/splice -p 'splice-cli-x86_64-linux-gnu' \
  -O ~/.local/bin/splice
chmod +x ~/.local/bin/splice
ldd ~/.local/bin/splice | grep "not found"   # must print nothing
```

### 4. Apple root certificate for Splice

`gsa.apple.com` chains to Apple's private **Apple Root CA**, which Ubuntu's trust store doesn't
include. Without it, Splice fails with `ssl connect failed: certificate verify failed`
(splice issue [#23](https://github.com/franklintra/splice/issues/23)).

```bash
mkdir -p ~/.config/splice
curl -fsSL https://www.apple.com/appleca/AppleIncRootCertificate.cer \
  | openssl x509 -inform DER > /tmp/apple-root-ca.pem
openssl x509 -in /tmp/apple-root-ca.pem -noout -fingerprint -sha256
# must print B0:B1:73:0E:CB:C7:FF:45:05:14:2C:49:F1:29:5E:6E:DA:6B:CA:ED:7E:2C:68:C5:BE:91:B5:A1:10:01:F0:24
cat /etc/ssl/certs/ca-certificates.crt /tmp/apple-root-ca.pem > ~/.config/splice/ca-with-apple.crt
echo "alias splice='SSL_CERT_FILE=\$HOME/.config/splice/ca-with-apple.crt splice'" >> ~/.bashrc
```

`tool/ios_fetch_build.sh` sets `SSL_CERT_FILE` itself, so the alias only matters when you
run `splice` by hand.

### 5. Local anisette server (Docker)

Splice has to identify itself to Apple like a Mac ("anisette" data). Neither built-in option
works here:

- Splice's own emulation gets a `503` from Apple, and Splice then **segfaults**.
- Public servers such as `ani.sidestore.io` return a **different device identity on every
  request**. Apple then asks for 2FA again after every code, in an endless loop (splice issue
  [#25](https://github.com/franklintra/splice/issues/25)).

A local server keeps one stable identity:

```bash
docker run -d --name anisette-v3 -p 127.0.0.1:6969:6969 \
  -v anisette-v3_data:/home/Alcoholic/.config/anisette-v3/lib/ dadoum/anisette-v3-server
```

The server is only reachable from this PC. It never sees your Apple ID or password. The volume
keeps the identity, so Apple doesn't ask for 2FA on every run. The fetch script starts the
container when it's stopped (e.g. after a reboot).

### 6. Splice login

Log in in a real terminal (it prompts for input):

```bash
splice --anisette-server http://127.0.0.1:6969 login   # the server is remembered as the default
```

- Use an Apple ID with a **trusted device**, e.g. your main ID, signed in to iCloud on the
  iPhone. The 2FA code arrives as a push on that device. You can also get one via
  Settings → your name → Sign-In & Security → Get Verification Code.
- An **SMS-only** Apple ID (no Apple device signed in) doesn't work: Splice's SMS path is
  unfinished (issue [#25](https://github.com/franklintra/splice/issues/25)).
- To see what happens: `splice --log-level debug login`.
- Apple expires the session now and then. When an automatic install hits that, the fetch
  script opens a terminal window running `splice login`: type the 2FA code from the iPhone
  there, the window closes, and the install continues (it gives up after 10 minutes).

### 7. IPA password in the keyring

```bash
tool/ios_fetch_build.sh --store-password   # asks for IPA_PASSWORD once
```

It is stored in the GNOME login keyring (`secret-tool`, attributes
`service=retrail-ios key=ipa-password`), not in a file.

### 8. Git hook (automatic fetch + install after a push)

```bash
git config core.hooksPath .githooks
```

This is needed once per clone.

### 9. iPhone

1. Connect it via USB and confirm **Trust this computer**.
2. Install the first build: `tool/ios_fetch_build.sh` (or `--install`).
3. **Developer Mode:** on iOS 16 the switch only appears **after** the first developer-signed
   app is installed, or when you first try to open it. Go to Settings → Privacy & Security →
   Developer Mode → on. The phone restarts; confirm "Turn On".
4. **Trust the Apple ID:** Settings → General → VPN & Device Management → your Apple ID →
   Trust.

---

## Daily use

**Normally: nothing to do.** Push app code to `main` (`lib/`, `ios/`, `assets/`, `pubspec.*`,
`l10n.yaml`) and leave the iPhone connected and **unlocked**. About 5–15 minutes later the new
build is installed, with a notification.

| Situation | Command |
|---|---|
| You pushed app code to `main` | nothing: the hook runs `--wait` for you |
| You pushed without the hook, or clicked "Run workflow" on GitHub | `tool/ios_fetch_build.sh --wait` |
| Start a build from the terminal | `tool/ios_fetch_build.sh --trigger` |
| Get the latest green build (and install it) | `tool/ios_fetch_build.sh` |
| The iPhone wasn't connected, install now | `tool/ios_fetch_build.sh --install` |
| Skip the hook for one push | `RETRAIL_NO_IOS_FETCH=1 git push` |

- `--wait` waits for the newest **running** build on `main`, whatever started it. A new build
  takes a few seconds to show up, so it looks for up to a minute; if none is running, it
  fetches the latest green build instead.
- `--trigger` starts the workflow on `main` itself and waits for exactly that build.
- **Network blips while waiting** (Wi-Fi drop, connection reset) don't count as a failed
  build: the run's own result decides, GitHub is re-asked every 30 s (up to ~10 min), and a
  still-running build is watched again. Only if GitHub stays unreachable does it give up with
  **"GitHub not reachable"** — run `tool/ios_fetch_build.sh` once the build is done.
- **Install step:** the script checks for an iPhone on USB (`idevice_id -l`).
  - **Connected:** it unpacks into a temp dir, starts `anisette-v3` if needed, runs
    `splice install`, deletes the unpacked `.ipa`, and notifies **"Retrail installed"**.
  - **Not connected:** it installs nothing and notifies **"iPhone not connected"**.
  - It remembers the installed build (`.installed-id`), so nothing is installed twice.
- **Notifications:** "build #n ready", "Retrail installed", "iPhone not connected",
  "install failed" (with the reason), "build failed" (with the reason and a link to the run),
  and "GitHub not reachable".
- **By hand, without the script:** GitHub → Actions → iOS build → latest green run →
  artifact `Retrail-ios-<n>`, then `unzip Retrail-ios-*.zip && 7z x Retrail.ipa.7z &&
  splice install Retrail.ipa`. Artifacts expire after **3 days**.

---

## What lives where

| What | Where |
|---|---|
| Fetch/install script | `tool/ios_fetch_build.sh` (repo) |
| Git hook | `.githooks/pre-push` (repo), enabled via `git config core.hooksPath` |
| CI workflow | `.github/workflows/ios-build.yml` (repo) |
| Downloaded build (encrypted) | `~/Downloads/retrail-ios/Retrail.ipa.7z` |
| Downloaded / installed build ids | `~/Downloads/retrail-ios/.artifact-id`, `.installed-id` |
| Log of background runs | `~/.cache/retrail-ios-fetch.log` |
| Splice binary | `~/.local/bin/splice` |
| Splice state: login, certificates, anisette setting | `~/.config/Sideloader/` |
| CA bundle with Apple's root | `~/.config/splice/ca-with-apple.crt` |
| `splice` alias | `~/.bashrc` (last line) |
| Anisette server | Docker container `anisette-v3`, volume `anisette-v3_data` |
| IPA password | GNOME login keyring (`service=retrail-ios key=ipa-password`) |
| GitHub secrets | `MAPTILER_KEY`, `IPA_PASSWORD` in the repo settings |

---

## Limits

- **7-day signature:** a free Apple ID signs for 7 days; after that the app no longer starts.
  Every automatic install re-signs it. Without a new build, re-sign with `splice refresh`
  (iPhone on USB, `anisette-v3` running).
- **10 App IDs per 7 days:** Splice reuses the existing ones. So far the app plus the Live
  Activity extension use 2.
- **iPhone 8 / iOS 16.7:**
  - The Live Activity shows on the lock screen, but **without buttons** (they need iOS 17).
  - There is **no Dynamic Island** (iPhone 14 Pro and later).
  - TrollStore-style permanent installs don't work (only up to iOS 16.6.1).
- **Keep the iPhone unlocked** while installing, or Splice fails ("install failed").
- **Community tooling:** Splice and the anisette server aren't Apple products and can break
  with new iOS versions.
- **Public repo:** artifacts are downloadable by any GitHub user, which is why the `.ipa` is
  AES-encrypted and only kept for 3 days. The MapTiler key is compiled into every build.

---

## Undoing it

Remove whatever you no longer want; the steps are independent.

| Undo | Command / action |
|---|---|
| Automatic fetch after a push | `git config --unset core.hooksPath` |
| Retrail on the iPhone | long-press the app → Remove App (deletes its data) |
| Trust in the Apple ID on the iPhone | Settings → General → VPN & Device Management → your ID → Delete App |
| Developer Mode | Settings → Privacy & Security → Developer Mode → off |
| "Trust this computer" | Settings → General → Transfer or Reset iPhone → Reset → Reset Location & Privacy |
| IPA password in the keyring | `secret-tool clear service retrail-ios key ipa-password` |
| Splice login | `splice logout` |
| Splice entirely | `rm ~/.local/bin/splice` and `rm -rf ~/.config/Sideloader ~/.config/splice`, then remove the `alias splice=…` line from `~/.bashrc` |
| Anisette server | `docker rm -f anisette-v3 && docker volume rm anisette-v3_data && docker rmi dadoum/anisette-v3-server` |
| Downloaded builds and log | `rm -rf ~/Downloads/retrail-ios ~/.cache/retrail-ios-fetch.log` |
| Apple development certificate | revoke it at developer.apple.com → Certificates (optional; it expires by itself) |
| iOS builds on GitHub | delete or disable `.github/workflows/ios-build.yml`; remove the secrets in the repo settings |
| Packages | `sudo apt remove libsecret-tools 7zip` (`usbmuxd` / `libimobiledevice-utils` may be used by other tools) |

---

## What to test on the phone (Spec 6 device checklist)

On an iPhone 8 / iOS 16.x, the items marked *(iOS 17+)* and *(Dynamic Island)* can't be tested.

- Start a ride and lock the phone → the Live Activity appears on the lock screen (and in the
  Dynamic Island).
- The timer ticks with the phone locked. The distance updates while you move.
- Pause in the app → "Ride paused", timer frozen. Lock-screen **Pause/Resume** *(iOS 17+)*.
- Stop (in the app, or on the lock screen *(iOS 17+)*) → the ride appears in the history, and
  the activity disappears.
- Tapping the activity opens the running ride.
- German phone language → German texts and a comma as decimal separator.
- Live Activities switched off (Settings → Retrail) → the ride still records.
- Force-quit the app during a ride and relaunch → no activity is left behind.
- Background recording with the screen off keeps drawing the route (Spec 5B).
