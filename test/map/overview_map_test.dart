import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/map/overview_map.dart';

void main() {
  tearDown(() => OverviewMap.debugMapBuilderOverride = null);

  testWidgets('the test seam replaces the native map', (tester) async {
    OverviewMap.debugMapBuilderOverride = (_) => const Text('fake map');
    await tester.pumpWidget(
      const MaterialApp(
        home: OverviewMap(
          linesByType: {},
          heat: null,
          bounds: null,
          frameToken: null,
        ),
      ),
    );
    expect(find.text('fake map'), findsOneWidget);
  });
}
