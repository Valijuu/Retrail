import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Builds Retrail's Material 3 [ThemeData] for the given [brightness].
///
/// Mirrors the original Android `Theme.kt`: it sets the brand [ColorScheme]
/// (dynamic color OFF) and stock M3 typography, and attaches the [AppColors]
/// token set as a theme extension. Shapes/component styling are applied
/// per-widget in the screen phases (the original defined no global component
/// themes), so the only global component tweak here is a seamless app bar that
/// blends into the surface — matching the original's status-bar behavior.
ThemeData buildTheme(Brightness brightness) {
  final tokens = brightness == Brightness.dark ? AppColors.dark : AppColors.light;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: tokens.primary,
    brightness: brightness,
  ).copyWith(
    primary: tokens.primary,
    onPrimary: tokens.onPrimary,
    primaryContainer: tokens.primaryContainer,
    onPrimaryContainer: tokens.onPrimaryContainer,
    surface: tokens.surface,
    onSurface: tokens.onSurface,
    onSurfaceVariant: tokens.onSurfaceVariant,
    // Original mapped Compose's `surfaceVariant` to the SurfaceContainer token;
    // the modern M3 slot is surfaceContainerHighest.
    surfaceContainerHighest: tokens.surfaceContainer,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: tokens.surface,
    textTheme: appTextTheme(brightness),
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.surface,
      foregroundColor: tokens.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    extensions: <ThemeExtension<dynamic>>[tokens],
  );
}
