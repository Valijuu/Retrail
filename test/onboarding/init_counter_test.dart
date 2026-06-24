import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/features/onboarding/init_screen.dart';
import 'package:retrail/l10n/app_localizations.dart';

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );

void main() {
  testWidgets('the N/30 counter reflects input and caps at 30', (tester) async {
    await tester.pumpWidget(_wrap(const InitScreen()));
    await tester.pumpAndSettle();

    expect(find.text('0/30'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump();
    expect(find.text('3/30'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'a' * 35);
    await tester.pump();
    expect(find.text('30/30'), findsOneWidget);
  });
}
