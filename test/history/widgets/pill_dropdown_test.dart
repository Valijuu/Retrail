import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_colors.dart';
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

  testWidgets('closed state has no legacy underline (DropdownButtonHideUnderline)',
      (tester) async {
    await pump(tester, value: 2);
    expect(find.byType(DropdownButtonHideUnderline), findsOneWidget);
  });

  testWidgets('tapping opens the menu with all item labels', (tester) async {
    await pump(tester, value: 1);
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();

    expect(find.text('Item 1'), findsWidgets);
    expect(find.text('Item 2'), findsOneWidget);
    expect(find.text('Item 3'), findsOneWidget);
  });

  testWidgets('the selected item is wrapped in a primaryContainer highlight',
      (tester) async {
    await pump(tester, value: 2);
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();

    final colors = AppColors.light;
    final highlighted = find.ancestor(
      of: find.text('Item 2').last,
      matching: find.byWidgetPredicate((w) =>
          w is Container &&
          (w.decoration as BoxDecoration?)?.color == colors.primaryContainer),
    );
    expect(highlighted, findsOneWidget);
  });

  testWidgets('an unselected item has no highlight container', (tester) async {
    await pump(tester, value: 2);
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();

    final colors = AppColors.light;
    final highlighted = find.ancestor(
      of: find.text('Item 3').last,
      matching: find.byWidgetPredicate((w) =>
          w is Container &&
          (w.decoration as BoxDecoration?)?.color == colors.primaryContainer),
    );
    expect(highlighted, findsNothing);
  });

  testWidgets('tapping an item calls onChanged with its value', (tester) async {
    int? changed;
    await pump(tester, value: 1, onChanged: (v) => changed = v);
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Item 3').last);
    await tester.pumpAndSettle();

    expect(changed, 3);
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
