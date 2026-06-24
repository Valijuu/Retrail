import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/app.dart';

void main() {
  testWidgets('RetrailApp boots and renders the app title', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: RetrailApp()));
    await tester.pumpAndSettle();

    // Proves Riverpod's ProviderScope, the MaterialApp, and localization
    // wiring all come up together: the placeholder home shows "Retrail".
    expect(find.text('Retrail'), findsOneWidget);
  });
}
