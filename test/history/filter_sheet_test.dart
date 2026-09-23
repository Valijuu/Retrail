import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/features/history/filter_sheet.dart';
import 'package:retrail/features/history/history_providers.dart';
import 'package:retrail/features/history/widgets/pill_dropdown.dart';
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

  testWidgets('shows a YEAR section with "All years" among the dropdown options',
      (tester) async {
    await pump(tester);
    expect(find.text('YEAR'), findsOneWidget);

    // The closed pill now shows the selected value (the current-year
    // default, see HistoryFilterNotifier) — "All years" is one of the
    // options, found once the menu is opened, not in the closed state.
    await tester.tap(find.byType(PillDropdown<int?>));
    await tester.pumpAndSettle();
    expect(find.text('All years'), findsOneWidget);
  });

  testWidgets('selecting a year in the dropdown updates historyFilterProvider',
      (tester) async {
    await pump(tester);

    await tester.tap(find.byType(PillDropdown<int?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2023').last);
    await tester.pumpAndSettle();

    expect(container.read(historyFilterProvider).year, 2023);
  });

  testWidgets(
      'week/month period chips stay visible by default (current year, no '
      'month range)', (tester) async {
    await pump(tester);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);
  });

  testWidgets('period chips are hidden when "All years" is explicitly selected',
      (tester) async {
    await pump(tester);
    container.read(historyFilterProvider.notifier).setYear(null);
    await tester.pump();
    expect(find.text('This week'), findsNothing);
    expect(find.text('This month'), findsNothing);
  });

  testWidgets('period chips stay visible when Von=Bis=the current month',
      (tester) async {
    final now = DateTime.now();
    await pump(tester, years: [now.year]);
    final notifier = container.read(historyFilterProvider.notifier);
    notifier.setMonthFrom(now.month);
    notifier.setMonthTo(now.month);
    await tester.pump();
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);
  });

  testWidgets(
      'period chips are hidden once the month range is narrowed to anything '
      'other than the current month', (tester) async {
    final now = DateTime.now();
    await pump(tester, years: [now.year]);
    // Setting only monthFrom already breaks "both null or both == current
    // month" — monthTo stays null, neither side of the rule is satisfied.
    container.read(historyFilterProvider.notifier).setMonthFrom(now.month);
    await tester.pump();
    expect(find.text('This week'), findsNothing);
    expect(find.text('This month'), findsNothing);
  });

  testWidgets(
      'week/month period chips, the PERIOD section label, and its '
      '"All" chip are all hidden once a PAST year is selected',
      (tester) async {
    await pump(tester);
    // Before: the PERIOD section is present — its label, plus two "All"
    // chips (one from PERIOD, one from ACTIVITY, both localized to "All").
    expect(find.text('PERIOD'), findsOneWidget);
    expect(find.text('All'), findsNWidgets(2));

    container.read(historyFilterProvider.notifier).setYear(2023);
    await tester.pump();

    expect(find.text('This week'), findsNothing);
    expect(find.text('This month'), findsNothing);
    // After: the whole PERIOD section is gone — its label, and its "All"
    // chip (only ACTIVITY's "All" chip remains).
    expect(find.text('PERIOD'), findsNothing);
    expect(find.text('All'), findsOneWidget);
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
    expect(find.byType(PillDropdown<int?>), findsOneWidget);
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
  });

  testWidgets(
      'Von/Bis month-range dropdowns are visible by default (current-year '
      'default)', (tester) async {
    await pump(tester);

    expect(find.text('MONTH RANGE'), findsOneWidget);
    // Year dropdown + Von + Bis = 3 PillDropdown<...> instances.
    expect(find.byType(PillDropdown<int?>), findsOneWidget);
    expect(find.byType(PillDropdown<int>), findsNWidgets(2));
  });

  testWidgets(
      'Von/Bis month-range dropdowns are hidden once "All years" is '
      'explicitly selected', (tester) async {
    await pump(tester);
    container.read(historyFilterProvider.notifier).setYear(null);
    await tester.pump();

    expect(find.text('MONTH RANGE'), findsNothing);
  });

  testWidgets(
      'Von/Bis month-range dropdowns stay visible for a PAST year (unlike '
      'the period chips)', (tester) async {
    await pump(tester);
    container.read(historyFilterProvider.notifier).setYear(2023);
    await tester.pump();

    expect(find.text('This week'), findsNothing); // period chips hidden
    expect(find.text('MONTH RANGE'), findsOneWidget); // month range shown
  });

  testWidgets(
      'Von/Bis month-range dropdowns coexist with period chips in the '
      'current year', (tester) async {
    final currentYear = DateTime.now().year;
    await pump(tester, years: [currentYear]);
    container.read(historyFilterProvider.notifier).setYear(currentYear);
    await tester.pump();

    expect(find.text('This week'), findsOneWidget);
    expect(find.text('MONTH RANGE'), findsOneWidget);
  });

  testWidgets('Von/Bis month-range dropdowns disappear back at "All years"',
      (tester) async {
    await pump(tester);
    final notifier = container.read(historyFilterProvider.notifier);
    notifier.setYear(2023);
    await tester.pump();
    expect(find.text('MONTH RANGE'), findsOneWidget);

    notifier.setYear(null);
    await tester.pump();
    expect(find.text('MONTH RANGE'), findsNothing);
  });

  testWidgets('selecting a "Von" month updates historyFilterProvider.monthFrom',
      (tester) async {
    await pump(tester);
    container.read(historyFilterProvider.notifier).setYear(2023);
    await tester.pump();

    await tester.tap(find.byType(PillDropdown<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('June').last);
    await tester.pumpAndSettle();

    expect(container.read(historyFilterProvider).monthFrom, 6);
  });

  testWidgets('a year change resets a previously chosen month range back to '
      'January/December', (tester) async {
    await pump(tester, years: [2023, 2024]);
    final notifier = container.read(historyFilterProvider.notifier);
    notifier.setYear(2023);
    notifier.setMonthFrom(6);
    notifier.setMonthTo(8);
    await tester.pump();
    expect(find.text('June'), findsOneWidget);

    notifier.setYear(2024);
    await tester.pump();

    expect(find.text('June'), findsNothing);
    expect(find.text('January'), findsOneWidget);
    expect(find.text('December'), findsOneWidget);
  });
}
