# Android release (Play Store)

App ID: `io.github.valijuu.retrail` — fixed once the first build is uploaded.

## Two keys

| Key | Who holds it | Used for |
|---|---|---|
| **App-signing key** | Google (Play App Signing) | Signs the app users install. Never leaves Google. |
| **Upload key** | you, locally | Signs every bundle you upload, so Play knows it comes from you. |

A lost or leaked upload key is recoverable: the account owner asks Play support
for an upload key reset (Play Console → Test and release → App integrity → App
signing → *Request upload key reset*, with a new certificate exported as PEM).
That takes a few days. Keep a backup anyway.

## The upload key on this machine

Created 2026-10-06:

| | |
|---|---|
| Keystore | `~/retrail-upload.jks` (PKCS12, RSA 2048, valid until 2054) |
| Alias | `upload` |
| Owner | `CN=Valijuu, O=Retrail` |
| SHA-256 | `DB:BA:13:5D:DE:ED:B1:A0:58:CB:72:E9:2E:E6:F1:84:6A:F1:1A:AA:0F:32:65:88:D5:8A:19:1F:7E:19:A0:61` |
| Passwords | in `android/key.properties` (store and key password are the same) |

Both files are outside git (`android/.gitignore` ignores `key.properties`,
`*.jks`, `*.keystore`) and `chmod 600`. **Back up** the `.jks` file (USB stick
or cloud storage) and copy the password into a password manager. Without both,
only an upload key reset helps.

### Recreate it (new machine, or after a reset)

On a new machine with the backup: copy the `.jks` to `~/retrail-upload.jks` and
write `android/key.properties` as below.

To create a new key (only before the first upload, or for an upload key reset),
`keytool` ships with any JDK (here `/usr/lib/jvm/java-17-openjdk-amd64/bin/keytool`):

```sh
PW=$(openssl rand -hex 24)
keytool -genkeypair -keystore ~/retrail-upload.jks -storetype PKCS12 \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload \
  -storepass "$PW" -keypass "$PW" -dname "CN=Valijuu, O=Retrail"
printf 'storePassword=%s\nkeyPassword=%s\nkeyAlias=upload\nstoreFile=%s\n' \
  "$PW" "$PW" "$HOME/retrail-upload.jks" > android/key.properties
chmod 600 android/key.properties ~/retrail-upload.jks
unset PW
```

`android/key.properties` (never commit):

```properties
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=/home/<you>/retrail-upload.jks
```

For an upload key reset, Play wants the new certificate as PEM:

```sh
keytool -export -rfc -keystore ~/retrail-upload.jks -alias upload \
  -file upload_certificate.pem
```

## How the build uses it

`android/app/build.gradle.kts` signs release builds with this key when
`key.properties` exists, and with the debug key otherwise (so
`flutter run --release` still works without it; Play rejects debug-signed
bundles).

## Build and check

```sh
tool/build_release.sh
```

It runs `flutter build appbundle --release`, checks with `keytool` that the
bundle is signed with the upload key above (`CN=Valijuu`), not
`CN=Android Debug`, and stores it as `release/retrail-<version>.aab`
(gitignored). Upload that file in the Play Console. Bump
`version:` in `pubspec.yaml` (the `+N` build number) for every upload.
