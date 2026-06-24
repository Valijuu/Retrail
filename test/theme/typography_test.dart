import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/core/theme/app_typography.dart';

void main() {
  group('typography', () {
    test('appTextTheme exposes the Material 3 roles used by the app', () {
      final t = appTextTheme(Brightness.light);
      // Roles referenced by the design-token mapping must all be present.
      for (final style in [
        t.titleLarge,
        t.titleSmall,
        t.titleMedium,
        t.displaySmall,
        t.bodyMedium,
        t.bodyLarge,
        t.labelLarge,
        t.labelSmall,
      ]) {
        expect(style, isNotNull);
      }
    });

    test('bodyLarge matches the original Type.kt (= M3 default 16/0.5)', () {
      final bodyLarge = appTextTheme(Brightness.light).bodyLarge!;
      expect(bodyLarge.fontSize, 16);
      expect(bodyLarge.letterSpacing, 0.5);
    });

    test('buildTheme wires the text theme in', () {
      final theme = buildTheme(Brightness.dark);
      expect(theme.textTheme.bodyLarge?.fontSize, 16);
    });
  });
}
