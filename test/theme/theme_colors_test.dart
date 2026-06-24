import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_colors.dart';
import 'package:retrail/core/theme/app_theme.dart';

void main() {
  group('buildTheme colorScheme mapping (mirrors original Theme.kt)', () {
    test('light maps tokens onto the M3 colorScheme slots', () {
      final s = buildTheme(Brightness.light).colorScheme;
      const t = AppColors.light;
      expect(s.brightness, Brightness.light);
      expect(s.primary, t.primary);
      expect(s.onPrimary, t.onPrimary);
      expect(s.primaryContainer, t.primaryContainer);
      expect(s.onPrimaryContainer, t.onPrimaryContainer);
      expect(s.surface, t.surface);
      expect(s.onSurface, t.onSurface);
      expect(s.onSurfaceVariant, t.onSurfaceVariant);
      // Original mapped surfaceVariant = SurfaceContainer; the modern slot is
      // surfaceContainerHighest.
      expect(s.surfaceContainerHighest, t.surfaceContainer);
    });

    test('dark maps the dark tokens', () {
      final s = buildTheme(Brightness.dark).colorScheme;
      const t = AppColors.dark;
      expect(s.brightness, Brightness.dark);
      expect(s.primary, t.primary);
      expect(s.surface, t.surface);
      expect(s.onSurfaceVariant, t.onSurfaceVariant);
      expect(s.surfaceContainerHighest, t.surfaceContainer);
    });

    test('app bar blends into the surface (seamless status bar)', () {
      final theme = buildTheme(Brightness.light);
      expect(theme.appBarTheme.backgroundColor, AppColors.light.surface);
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.scaffoldBackgroundColor, AppColors.light.surface);
    });

    test('dynamic color is off — primary is the brand color, not seed-derived',
        () {
      // Brand primary is preserved exactly (not tonally adjusted by fromSeed).
      expect(buildTheme(Brightness.light).colorScheme.primary,
          const Color(0xFFB45309));
    });
  });
}
