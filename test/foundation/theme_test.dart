import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_colors.dart';
import 'package:retrail/core/theme/app_theme.dart';

void main() {
  group('buildTheme', () {
    test('light theme exposes the light AppColors tokens', () {
      final theme = buildTheme(Brightness.light);
      final colors = theme.extension<AppColors>();

      expect(colors, isNotNull);
      expect(theme.brightness, Brightness.light);
      expect(colors!.primary, const Color(0xFFB45309));
      expect(colors.surface, const Color(0xFFFFF8F5));
      // Route colors are theme-independent.
      expect(colors.routeLineBlue, const Color(0xFF2563EB));
    });

    test('dark theme exposes the dark AppColors tokens', () {
      final theme = buildTheme(Brightness.dark);
      final colors = theme.extension<AppColors>();

      expect(colors, isNotNull);
      expect(theme.brightness, Brightness.dark);
      expect(colors!.primary, const Color(0xFFF59E42));
      expect(colors.surface, const Color(0xFF1C1B1F));
      expect(colors.routeLineBlue, const Color(0xFF2563EB));
    });

    test('uses Material 3', () {
      expect(buildTheme(Brightness.light).useMaterial3, isTrue);
    });
  });
}
