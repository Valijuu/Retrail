import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_colors.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/core/widgets/app_snack_bar.dart';

void main() {
  testWidgets('appSnackBar leads with a tinted icon and keeps the close icon',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                appSnackBar(icon: Icons.check_circle, message: 'Saved')),
            child: const Text('show'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();

    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.showCloseIcon, isTrue);
    expect(bar.persist, isFalse);
    expect(find.text('Saved'), findsOneWidget);
    final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle));
    expect(icon.color, AppColors.light.primary);
  });
}
