---
title: A Flutter upgrade does not fix the Play edge-to-edge deprecation hint
author: Valiju
date: 2026-10-31
branch: main
cost: { minutes: 1, tokens: 957 }
id: l-03699a89
scope: repo
status: active
src: agent
touches:
  - android/app/build.gradle.kts
---

## Tried and ruled out
Upgrading Flutter 3.44.3 to 3.47.9 to make the Play Console "deprecated edge-to-edge APIs" hint (#83) go away. The release bundle still contains setStatusBarColor, setNavigationBarColor and setDecorFitsSystemWindows after the upgrade, so it was not adopted. The calls live in the Flutter embedding (PlatformPlugin, FlutterActivity), not in app code or plugins.

In the code: checked by unpacking the built .aab and grepping the dex strings, and by grepping the flutter_embedding_release jar in ~/.gradle/caches/modules-2/files-2.1/io.flutter. Re-check after future Flutter stable releases (#83).

## Watch out
Running flutter with 3.47.9 rewrites pubspec.lock (test packages) and adds build/, android/, ios/ to the analyzer excludes in analysis_options.yaml. Those edits are side effects of the SDK, not intended changes, so they were reverted with git checkout. Do not commit them by accident.
