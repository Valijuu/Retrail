import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_colors.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/core/theme/theme_context.dart';

void main() {
  testWidgets('context.colors returns the AppColors extension from the theme',
      (tester) async {
    late AppColors fromContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Builder(
          builder: (context) {
            fromContext = context.colors;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(fromContext.primary, AppColors.light.primary);
    expect(fromContext.routeLineBlue, AppColors.light.routeLineBlue);
  });
}
