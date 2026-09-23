import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_colors.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/features/active_ride/widgets/ride_chrome.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
        '$brightness: banner text uses the paired on-colour, readable on the '
        'banner fill (white was unreadable on the light dark-mode fill)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(brightness),
        home: const Scaffold(body: RideWarningBanner(label: 'Warn')),
      ));
      final colors =
          Theme.of(tester.element(find.text('Warn'))).extension<AppColors>()!;
      final text = tester.widget<Text>(find.text('Warn'));
      expect(text.style?.color, colors.editActionBg);
    });
  }
}
