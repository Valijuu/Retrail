import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/app.dart';
import 'package:retrail/core/connectivity/connectivity_providers.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:retrail/features/shell/startup_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/home_test_helpers.dart';

void main() {
  testWidgets('a pending ride deep-link routes to /ride and clears the flag',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({'onboarding_done': true});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      preferencesRepositoryProvider
          .overrideWithValue(PreferencesRepository(prefs)),
      isOnlineProvider.overrideWith((ref) => Stream.value(true)),
      ...activeRideTestOverrides(db),
      ...homeStreamStubs(),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const RetrailApp()),
    );
    // The home screen never settles, so pump fixed windows instead of settling.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Onboarding done → main shell.
    expect(find.text('Home'), findsOneWidget);

    container.read(pendingRideDeepLinkProvider.notifier).state = true;
    await tester.pump(); // redirect
    await tester.pump(const Duration(milliseconds: 200)); // fade transition
    await tester.pump(); // active-ride post-frame: clear the flag

    expect(find.text('Retrail ride'), findsOneWidget);
    expect(container.read(pendingRideDeepLinkProvider), isFalse);
  });
}
