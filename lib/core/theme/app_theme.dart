import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Builds Retrail's Material 3 [ThemeData] for the given [brightness], with the
/// [AppColors] token set attached as a theme extension.
///
/// Full typography and shape wiring lands in Spec 2 (design system); this
/// foundation build only needs a valid M3 theme that exposes the tokens.
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
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: tokens.surface,
    extensions: <ThemeExtension<dynamic>>[tokens],
  );
}
