# Android release (Play Store)

App ID: `io.github.valijuu.retrail` — fixed once the first build is uploaded.

## Upload key (one time)

Play App Signing holds the real app-signing key; you sign uploads with your
own **upload key**. If it is lost, Play support can reset it, but keep a backup
(password manager + an offline copy) anyway.

```sh
keytool -genkey -v -keystore ~/retrail-upload.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias upload
```

Then create `android/key.properties` (gitignored, never commit):

```properties
storePassword=<keystore password>
keyPassword=<key password>
keyAlias=upload
storeFile=/home/<you>/retrail-upload.jks
```

`android/app/build.gradle.kts` signs release builds with this key when
`key.properties` exists, and with the debug key otherwise (so
`flutter run --release` still works; Play rejects debug-signed bundles).

## Build

```sh
flutter build appbundle --release --dart-define-from-file=maptiler.json
```

Upload `build/app/outputs/bundle/release/app-release.aab` in the Play Console.
Bump `version:` in `pubspec.yaml` (the `+N` build number) for every upload.
