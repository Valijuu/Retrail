import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/features/history/filter_sheet.dart';
import 'package:retrail/features/history/history_providers.dart';
import 'package:retrail/l10n/app_localizations.dart';

/// Standalone widget tests for the year picker + period-chip hiding added to
/// [HistoryFilterSheet]. Stubs [availableHistoryYearsProvider] with a finite
/// stream (Drift `.watch()` never closes — see the established test rule).
void main() {
  late ProviderContainer container;

  tearDown(() => container.dispose());

  Future<void> pump(
    WidgetTester tester, {
    List<int> years = const [2024, 2023],
  }) async {
    container = ProviderContainer(overrides: [
      availableHistoryYearsProvider.overrideWith((ref) => Stream.value(years)),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: HistoryFilterSheet()),
      ),
    ));
    await tester.pump();
  }

  testWidgets('shows a YEAR section with "All years" + the available years',
      (tester) async {
    await pump(tester);
    expect(find.text('YEAR'), findsOneWidget);
    expect(find.text('All years'), findsOneWidget);
  });

  testWidgets('selecting a year in the dropdown updates historyFilterProvider',
      (tester) async {
    await pump(tester);

    await tester.tap(find.byType(DropdownButton<int?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2023').last);
    await tester.pumpAndSettle();

    expect(container.read(historyFilterProvider).year, 2023);
  });

  testWidgets('week/month/year period chips stay visible with no year filter',
      (tester) async {
    await pump(tester);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);
    expect(find.text('This year'), findsOneWidget);
  });

  testWidgets(
      'week/month/year period chips are hidden once a PAST year is selected',
      (tester) async {
    await pump(tester);
    container.read(historyFilterProvider.notifier).setYear(2023);
    await tester.pump();

    expect(find.text('This week'), findsNothing);
    expect(find.text('This month'), findsNothing);
    expect(find.text('This year'), findsNothing);
  });

  testWidgets(
      'does not crash when the selected year is no longer in the available '
      'years (e.g. its rides were just bulk-deleted)', (tester) async {
    await pump(tester, years: const [2024, 2023]);
    container.read(historyFilterProvider.notifier).setYear(2023);
    await tester.pump();
    // Simulate the year's rides having all just been deleted: the provider
    // now only reports 2024.
    container.updateOverrides([
      availableHistoryYearsProvider
          .overrideWith((ref) => Stream.value(const [2024])),
    ]);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(DropdownButton<int?>), findsOneWidget);
  });

  testWidgets(
      'period chips stay visible when the selected year is the current year',
      (tester) async {
    final currentYear = DateTime.now().year;
    await pump(tester, years: [currentYear, currentYear - 1]);
    container.read(historyFilterProvider.notifier).setYear(currentYear);
    await tester.pump();

    expect(find.text('This week'), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);
    expect(find.text('This year'), findsOneWidget);
  });
}
