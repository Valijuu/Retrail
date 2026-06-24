import 'package:flutter/material.dart';

/// Retrail uses stock **Material 3 (2021) typography**. The original Android
/// `Type.kt` "overrode" only `bodyLarge`, with values identical to the M3
/// default (16sp / 24 line-height / 0.5 letter-spacing), so no real overrides
/// are needed.
///
/// Role → usage mapping (applied per-widget in the screen phases):
/// - `titleLarge`   → page title ("Retrail")
/// - `labelSmall`   → greeting, section labels, card metadata (dimmed)
/// - `displaySmall` → hero number (e.g. 24.3 km)
/// - `titleSmall`   → hero unit (dimmed)
/// - `bodyMedium`   → card title (medium weight)
/// - `labelLarge`   → primary button
/// - `titleMedium`  → stat value
TextTheme appTextTheme(Brightness brightness) {
  // The M3 type scale lives in the geometry theme (englishLike2021) — sizes &
  // spacing — which must be merged with the brightness color theme to get the
  // fully-resolved styles Flutter renders.
  final typography = Typography.material2021(platform: TargetPlatform.android);
  final colorTheme =
      brightness == Brightness.dark ? typography.white : typography.black;
  return typography.englishLike.merge(colorTheme);
}
