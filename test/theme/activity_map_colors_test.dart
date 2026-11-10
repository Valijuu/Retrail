import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_colors.dart';
import 'package:retrail/domain/activity_type.dart';

void main() {
  for (final brightness in Brightness.values) {
    test(
      'all nine types have a distinct colour on the ${brightness.name} map',
      () {
        final colors = {
          for (final type in ActivityType.values)
            ActivityMapColors.of(type, brightness),
        };
        expect(colors, hasLength(ActivityType.values.length));
      },
    );
  }

  test('the dark map uses lighter tones than the light map', () {
    for (final type in ActivityType.values) {
      final light = HSLColor.fromColor(
        ActivityMapColors.of(type, Brightness.light),
      ).lightness;
      final dark = HSLColor.fromColor(
        ActivityMapColors.of(type, Brightness.dark),
      ).lightness;
      expect(dark, greaterThan(light), reason: type.id);
    }
  });
}
