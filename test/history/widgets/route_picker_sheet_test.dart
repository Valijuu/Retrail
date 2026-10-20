import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/db/followed_route.dart';
import 'package:retrail/features/history/history_providers.dart';
import 'package:retrail/features/history/route_group_providers.dart';
import 'package:retrail/features/history/widgets/route_picker_sheet.dart';
import 'package:retrail/l10n/app_localizations.dart';

const _june12 = 1718193600000;

FollowedRoute _route(int id, String? title, {int rides = 2}) => FollowedRoute(
  // No route preview in tests: the thumbnail shows its placeholder.
  original: Ride(
    rideId: id,
    description: title,
    date: _june12,
    isFavorite: false,
    hasRoute: false,
  ),
  rideCount: rides,
  lastRiddenMs: _june12,
);

void main() {
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester, {Set<int> selected = const {}}) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container = ProviderContainer(
      overrides: [
        followedRoutesProvider.overrideWith(
          (ref) => Stream.value([
            _route(1, 'Hausrunde', rides: 3),
            _route(2, 'Rheinufer'),
            _route(3, null),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(historyFilterProvider.notifier).setRouteIds(selected);
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
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showRoutePickerSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder row(int id) => find.byKey(ValueKey('route_picker_row_$id'));
  bool checked(WidgetTester tester, int id) => tester
      .widget<Checkbox>(
        find.descendant(of: row(id), matching: find.byType(Checkbox)),
      )
      .value!;

  testWidgets('lists every followed route with its rides and last date', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Hausrunde'), findsOneWidget);
    expect(find.text('Rheinufer'), findsOneWidget);
    expect(find.text('Wednesday, June 12, 2024'), findsOneWidget);
    expect(find.text('3 rides · 12.06.2024'), findsOneWidget);
  });

  testWidgets('the current filter is checked', (tester) async {
    await pump(tester, selected: {2});
    expect(checked(tester, 2), isTrue);
    expect(checked(tester, 1), isFalse);
  });

  testWidgets('the search narrows the list', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'haus');
    await tester.pump();
    expect(row(1), findsOneWidget);
    expect(row(2), findsNothing);
    expect(row(3), findsNothing);
  });

  testWidgets('a search without a match says so', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pump();
    expect(find.text('No route matches'), findsOneWidget);
  });

  testWidgets('choosing several routes applies only on Apply', (tester) async {
    await pump(tester);
    await tester.tap(row(1));
    await tester.tap(row(3));
    await tester.pump();
    expect(container.read(historyFilterProvider).routeIds, isEmpty);

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(container.read(historyFilterProvider).routeIds, {1, 3});
    expect(row(1), findsNothing); // closed
  });

  testWidgets('a second tap unchecks a route', (tester) async {
    await pump(tester, selected: {1});
    await tester.tap(row(1));
    await tester.pump();
    expect(checked(tester, 1), isFalse);
  });

  testWidgets('Reset unchecks all; Apply then shows every ride', (
    tester,
  ) async {
    await pump(tester, selected: {1, 2});
    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(checked(tester, 1), isFalse);
    expect(checked(tester, 2), isFalse);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(container.read(historyFilterProvider).routeIds, isEmpty);
  });
}
