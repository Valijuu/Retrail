import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/features/history/filter_sheet.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/db/followed_route.dart';
import 'package:retrail/features/history/history_providers.dart';
import 'package:retrail/features/history/route_group_providers.dart';
import 'package:retrail/features/history/widgets/route_picker_sheet.dart';
import 'package:retrail/features/history/widgets/pill_dropdown.dart';
import 'package:retrail/l10n/app_localizations.dart';

/// Standalone widget tests for the year picker and Von/Bis month-range
/// dropdowns in [HistoryFilterSheet]. Stubs [availableHistoryYearsProvider]
/// with a finite stream (Drift `.watch()` never closes — see the
/// established test rule).
void main() {
  late ProviderContainer container;

  tearDown(() => container.dispose());

  Future<void> pump(
    WidgetTester tester, {
    List<int> years = const [2024, 2023],
    List<FollowedRoute> routes = const [],
  }) async {
    container = ProviderContainer(
      overrides: [
        availableHistoryYearsProvider.overrideWith(
          (ref) => Stream.value(years),
        ),
        followedRoutesProvider.overrideWith((ref) => Stream.value(routes)),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
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
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'activity chips with a glyph draw no checkmark over it (issue #29)',
    (tester) async {
      await pump(tester);
      final glyphChips = tester
          .widgetList<FilterChip>(find.byType(FilterChip))
          .where((c) => c.avatar != null)
          .toList();
      expect(glyphChips, isNotEmpty);
      expect(glyphChips.every((c) => c.showCheckmark == false), isTrue);
    },
  );

  testWidgets(
    'shows a YEAR section with "All years" among the dropdown options',
    (tester) async {
      await pump(tester);
      expect(find.text('YEAR'), findsOneWidget);

      // The closed pill shows the selected value, which is "All years" by
      // default (see HistoryFilterNotifier).
      expect(find.text('All years'), findsOneWidget);

      // Opening the menu adds the "All years" option itself alongside the
      // closed pill's label.
      await tester.tap(find.byType(PillDropdown<int?>));
      await tester.pumpAndSettle();
      expect(find.text('All years'), findsNWidgets(2));
    },
  );

  testWidgets(
    'selecting a year in the dropdown updates historyFilterProvider',
    (tester) async {
      await pump(tester);

      await tester.tap(find.byType(PillDropdown<int?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2023').last);
      await tester.pumpAndSettle();

      expect(container.read(historyFilterProvider).year, 2023);
    },
  );

  testWidgets(
    'does not crash when the selected year is no longer in the available '
    'years (e.g. its rides were just bulk-deleted)',
    (tester) async {
      await pump(tester, years: const [2024, 2023]);
      container.read(historyFilterProvider.notifier).setYear(2023);
      await tester.pump();
      // Simulate the year's rides having all just been deleted: the provider
      // now only reports 2024.
      container.updateOverrides([
        availableHistoryYearsProvider.overrideWith(
          (ref) => Stream.value(const [2024]),
        ),
        followedRoutesProvider.overrideWith((ref) => Stream.value(const [])),
      ]);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(PillDropdown<int?>), findsOneWidget);
    },
  );

  testWidgets(
    'Von/Bis month-range dropdowns are visible by default ("All years" '
    'default)',
    (tester) async {
      await pump(tester);

      expect(find.text('MONTH RANGE'), findsOneWidget);
      // Year dropdown + Von + Bis = 3 PillDropdown<...> instances.
      expect(find.byType(PillDropdown<int?>), findsOneWidget);
      expect(find.byType(PillDropdown<int>), findsNWidgets(2));
    },
  );

  testWidgets('Von/Bis month-range dropdowns stay visible once "All years" is '
      'explicitly selected (they become a cross-year "these months, every '
      'year" filter)', (tester) async {
    await pump(tester);
    container.read(historyFilterProvider.notifier).setYear(null);
    await tester.pump();

    expect(find.text('MONTH RANGE'), findsOneWidget);
    expect(find.byType(PillDropdown<int?>), findsOneWidget);
    expect(find.byType(PillDropdown<int>), findsNWidgets(2));
  });

  testWidgets('Von/Bis month-range dropdowns stay visible for a PAST year', (
    tester,
  ) async {
    await pump(tester);
    container.read(historyFilterProvider.notifier).setYear(2023);
    await tester.pump();

    expect(find.text('MONTH RANGE'), findsOneWidget);
  });

  testWidgets('Von/Bis month-range dropdowns stay visible across every year '
      'selection, including switching back to "All years"', (tester) async {
    await pump(tester);
    final notifier = container.read(historyFilterProvider.notifier);
    notifier.setYear(2023);
    await tester.pump();
    expect(find.text('MONTH RANGE'), findsOneWidget);

    notifier.setYear(null);
    await tester.pump();
    expect(find.text('MONTH RANGE'), findsOneWidget);
  });

  testWidgets('there is visible spacing between MONTH RANGE and SORT BY', (
    tester,
  ) async {
    await pump(tester);

    final sortLabelTop = tester.getTopLeft(find.text('SORT BY')).dy;
    final monthRangeBottom = tester
        .getBottomLeft(find.byType(PillDropdown<int>).last)
        .dy;

    expect(sortLabelTop - monthRangeBottom, greaterThanOrEqualTo(20));
  });

  testWidgets(
    'selecting a "Von" month updates historyFilterProvider.monthFrom',
    (tester) async {
      await pump(tester);
      container.read(historyFilterProvider.notifier).setYear(2023);
      await tester.pump();

      await tester.tap(find.byType(PillDropdown<int>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('June').last);
      await tester.pumpAndSettle();

      expect(container.read(historyFilterProvider).monthFrom, 6);
    },
  );

  testWidgets(
    'a year change keeps a previously chosen month range (a month means '
    'the same thing regardless of year)',
    (tester) async {
      await pump(tester, years: [2023, 2024]);
      final notifier = container.read(historyFilterProvider.notifier);
      notifier.setYear(2023);
      notifier.setMonthFrom(6);
      notifier.setMonthTo(8);
      await tester.pump();
      expect(find.text('June'), findsOneWidget);
      expect(find.text('August'), findsOneWidget);

      notifier.setYear(2024);
      await tester.pump();

      expect(find.text('June'), findsOneWidget);
      expect(find.text('August'), findsOneWidget);
    },
  );

  group('followed routes (Spec 20)', () {
    FollowedRoute route(int id, String title) => FollowedRoute(
      original: Ride(
        rideId: id,
        description: title,
        date: 1718193600000,
        isFavorite: false,
        hasRoute: false,
      ),
      rideCount: 2,
      lastRiddenMs: 1718193600000,
    );
    final routes = [
      route(1, 'Hausrunde'),
      route(2, 'Rheinufer'),
      route(3, 'Stadt'),
    ];

    testWidgets('no followed routes: no section', (tester) async {
      await pump(tester);
      expect(find.text('FOLLOWED ROUTES'), findsNothing);
    });

    testWidgets('unfiltered, the row says all routes', (tester) async {
      await pump(tester, routes: routes);
      expect(find.text('FOLLOWED ROUTES'), findsOneWidget);
      expect(find.text('All routes'), findsOneWidget);
    });

    testWidgets('up to two chosen routes are named', (tester) async {
      await pump(tester, routes: routes);
      container.read(historyFilterProvider.notifier).setRouteIds({1, 2});
      await tester.pump();
      expect(find.text('Hausrunde, Rheinufer'), findsOneWidget);
    });

    testWidgets('more chosen routes are counted', (tester) async {
      await pump(tester, routes: routes);
      container.read(historyFilterProvider.notifier).setRouteIds({1, 2, 3});
      await tester.pump();
      expect(find.text('3 routes'), findsOneWidget);
    });

    testWidgets('tapping the row opens the route picker', (tester) async {
      await pump(tester, routes: routes);
      await tester.ensureVisible(find.text('All routes'));
      await tester.tap(find.text('All routes'));
      await tester.pumpAndSettle();
      expect(find.byType(RoutePickerSheet), findsOneWidget);
    });
  });
}
