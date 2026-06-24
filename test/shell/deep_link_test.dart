import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/app.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:retrail/features/shell/startup_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('a pending ride deep-link routes to /ride and clears the flag',
      (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_done': true});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      preferencesRepositoryProvider
          .overrideWithValue(PreferencesRepository(prefs)),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const RetrailApp()),
    );
    await tester.pumpAndSettle();
    // Onboarding done → main shell.
    expect(find.text('Home'), findsOneWidget);

    container.read(pendingRideDeepLinkProvider.notifier).state = true;
    await tester.pumpAndSettle();

    expect(find.text('ride'), findsOneWidget);
    expect(container.read(pendingRideDeepLinkProvider), isFalse);
  });
}
