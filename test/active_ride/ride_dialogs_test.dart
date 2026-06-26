import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/features/active_ride/ride_dialogs.dart';
import 'package:retrail/l10n/app_localizations.dart';

Widget _host(Widget child) => MaterialApp(
      theme: buildTheme(Brightness.light),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('ConfirmStopDialog renders and fires callbacks', (tester) async {
    var dismissed = false;
    var confirmed = false;
    await tester.pumpWidget(_host(ConfirmStopDialog(
      onDismiss: () => dismissed = true,
      onConfirm: () => confirmed = true,
    )));
    expect(find.text('Stop ride?'), findsOneWidget);
    expect(find.text('Do you want to stop the current ride?'), findsOneWidget);

    await tester.tap(find.text('Keep riding'));
    expect(dismissed, isTrue);
    await tester.tap(find.text('Stop'));
    expect(confirmed, isTrue);
  });

  testWidgets('DiscardRideConfirmDialog renders and fires confirm',
      (tester) async {
    var confirmed = false;
    await tester.pumpWidget(_host(DiscardRideConfirmDialog(
      onDismiss: () {},
      onConfirm: () => confirmed = true,
    )));
    expect(find.text('Discard ride?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    expect(confirmed, isTrue);
  });

  testWidgets('PostRideSummaryDialog saves entered title/comment/favorite',
      (tester) async {
    String? savedTitle;
    String? savedComment;
    bool? savedFav;
    await tester.pumpWidget(_host(PostRideSummaryDialog(
      onSkip: () {},
      onDiscard: () {},
      onSave: (t, c, f) {
        savedTitle = t;
        savedComment = c;
        savedFav = f;
      },
    )));

    expect(find.text('How was your ride?'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Sunset cruise');
    await tester.enterText(find.byType(TextField).last, 'Felt great');
    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pump();
    await tester.tap(find.text('Save'));

    expect(savedTitle, 'Sunset cruise');
    expect(savedComment, 'Felt great');
    expect(savedFav, isTrue);
  });

  testWidgets('PostRideSummaryDialog caps the title at 60 chars',
      (tester) async {
    String? savedTitle;
    await tester.pumpWidget(_host(PostRideSummaryDialog(
      onSkip: () {},
      onDiscard: () {},
      onSave: (t, c, f) => savedTitle = t,
    )));
    await tester.enterText(find.byType(TextField).first, 'x' * 80);
    await tester.tap(find.text('Save'));
    expect(savedTitle!.length, 60);
  });

  testWidgets('PostRideSummaryDialog Skip and Discard fire', (tester) async {
    var skipped = false;
    var discarded = false;
    await tester.pumpWidget(_host(PostRideSummaryDialog(
      onSkip: () => skipped = true,
      onDiscard: () => discarded = true,
      onSave: (t, c, f) {},
    )));
    await tester.tap(find.text('Skip'));
    expect(skipped, isTrue);
    await tester.tap(find.text('Discard ride'));
    expect(discarded, isTrue);
  });
}
