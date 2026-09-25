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

  group('overlay tokens (identical in both themes)', () {
    test('scrim is opaque black — dialog barriers apply their own alpha', () {
      expect(AppColors.light.scrim, const Color(0xFF000000));
      expect(AppColors.dark.scrim, AppColors.light.scrim);
    });

    test('onMap is white — marker rings, badge glyph, buttons over the map',
        () {
      expect(AppColors.light.onMap, const Color(0xFFFFFFFF));
      expect(AppColors.dark.onMap, AppColors.light.onMap);
    });

    test('routeArrow is a light grey that reads on the blue route line',
        () {
      expect(AppColors.light.routeArrow, const Color(0xFFE5E7EB));
      expect(AppColors.dark.routeArrow, AppColors.light.routeArrow);
      expect(AppColors.light.copyWith(routeArrow: const Color(0xFF000000))
          .routeArrow, const Color(0xFF000000));
    });

    test('copyWith and lerp carry the overlay tokens', () {
      const red = Color(0xFFFF0000);
      final changed = AppColors.light.copyWith(scrim: red, onMap: red);
      expect(changed.scrim, red);
      expect(changed.onMap, red);
      final mid = AppColors.light.lerp(changed, 1.0);
      expect(mid.scrim, red);
      expect(mid.onMap, red);
    });
  });
}
