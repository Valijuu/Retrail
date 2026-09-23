import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/features/history/widgets/pill_dropdown.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required int value,
    List<int> items = const [1, 2, 3],
    ValueChanged<int>? onChanged,
  }) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(
        body: PillDropdown<int>(
          value: value,
          items: items,
          itemLabel: (i) => 'Item $i',
          onChanged: onChanged ?? (_) {},
        ),
      ),
    ));
  }

  testWidgets('shows the selected value\'s label in the closed state',
      (tester) async {
    await pump(tester, value: 2);
    expect(find.text('Item 2'), findsOneWidget);
  });

  testWidgets('tapping opens the menu with all item labels', (tester) async {
    await pump(tester, value: 1);
    await tester.tap(find.byType(PillDropdown<int>));
    await tester.pumpAndSettle();

    expect(find.text('Item 1'), findsWidgets);
    expect(find.text('Item 2'), findsOneWidget);
    expect(find.text('Item 3'), findsOneWidget);
  });

  testWidgets(
      'the selected item is wrapped in a secondaryContainer highlight '
      '(matches the FilterChip selected-state color used elsewhere in the '
      'filter sheet)', (tester) async {
    await pump(tester, value: 2);
    await tester.tap(find.byType(PillDropdown<int>));
    await tester.pumpAndSettle();

    final secondaryContainer =
        buildTheme(Brightness.light).colorScheme.secondaryContainer;
    final highlighted = find.ancestor(
      of: find.text('Item 2').last,
      matching: find.byWidgetPredicate((w) =>
          w is Container &&
          (w.decoration as BoxDecoration?)?.color == secondaryContainer),
    );
    expect(highlighted, findsOneWidget);
  });

  testWidgets('an unselected item has no highlight container', (tester) async {
    await pump(tester, value: 2);
    await tester.tap(find.byType(PillDropdown<int>));
    await tester.pumpAndSettle();

    final secondaryContainer =
        buildTheme(Brightness.light).colorScheme.secondaryContainer;
    final highlighted = find.ancestor(
      of: find.text('Item 3').last,
      matching: find.byWidgetPredicate((w) =>
          w is Container &&
          (w.decoration as BoxDecoration?)?.color == secondaryContainer),
    );
    expect(highlighted, findsNothing);
  });

  testWidgets('tapping an item calls onChanged with its value', (tester) async {
    int? changed;
    await pump(tester, value: 1, onChanged: (v) => changed = v);
    await tester.tap(find.byType(PillDropdown<int>));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Item 3').last);
    await tester.pumpAndSettle();

    expect(changed, 3);
  });

  testWidgets('the menu closes after tapping an item', (tester) async {
    await pump(tester, value: 1);
    await tester.tap(find.byType(PillDropdown<int>));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Item 2').last);
    await tester.pumpAndSettle();

    // Closed state now shows only "Item 2" (the new value) — "Item 3" (a
    // different, still-unselected entry) must no longer be present anywhere
    // once the menu has closed.
    expect(find.text('Item 3'), findsNothing);
  });

  testWidgets(
      'menu opens below the anchor when the selected value is first in items',
      (tester) async {
    await pump(tester, value: 1, items: const [1, 2, 3, 4, 5]);
    final anchorBottomY =
        tester.getBottomLeft(find.byType(PillDropdown<int>)).dy;

    await tester.tap(find.byType(PillDropdown<int>));
    await tester.pumpAndSettle();

    final firstItemTopY = tester.getTopLeft(find.text('Item 1').last).dy;
    expect(firstItemTopY, greaterThanOrEqualTo(anchorBottomY - 1));
  });

  testWidgets(
      'menu opens below the anchor when the selected value is last in items '
      '(regression: DropdownButton used to open this case upward instead, '
      'aligning the menu on the selected item)', (tester) async {
    await pump(tester, value: 5, items: const [1, 2, 3, 4, 5]);
    final anchorBottomY =
        tester.getBottomLeft(find.byType(PillDropdown<int>)).dy;

    await tester.tap(find.byType(PillDropdown<int>));
    await tester.pumpAndSettle();

    final firstItemTopY = tester.getTopLeft(find.text('Item 1').last).dy;
    expect(firstItemTopY, greaterThanOrEqualTo(anchorBottomY - 1));
  });

  testWidgets('works with a nullable T (e.g. int?) for a "clear" item',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(
        body: PillDropdown<int?>(
          value: null,
          items: const [null, 2023, 2024],
          itemLabel: (y) => y == null ? 'All years' : '$y',
          onChanged: (_) {},
        ),
      ),
    ));

    expect(find.text('All years'), findsOneWidget);
  });
}
