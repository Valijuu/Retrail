import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/domain/activity_type.dart';
import 'package:retrail/features/onboarding/activity_type_ui.dart';
import 'package:retrail/features/timer/widgets/countdown_chips.dart';
import 'package:retrail/l10n/app_localizations.dart';

void main() {
  testWidgets('the countdown chip shows every activity type (#94)', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    for (final type in ActivityType.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.dark),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: CountdownActivityChip(activity: type)),
        ),
      );
      expect(find.text(type.label(l10n)), findsOneWidget, reason: type.id);
    }
  });
}
