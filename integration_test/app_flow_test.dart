import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:retrail/app.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:retrail/features/active_ride/active_ride_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// On-device integration skeleton for the full app flow, the real-UI counterpart
/// to the headless `test/e2e/record_save_history_preview_test.dart`.
///
/// **This is a Part B (device-gated) deliverable.** It is intentionally NOT part
/// of the phase green-gate: `flutter test` only runs `test/`, and this file lives
/// in `integration_test/`, run via `flutter test integration_test` on a real
/// device or emulator. It compiles and gives Spec 5B/6 a home.
///
/// The boot smoke below runs anywhere. The full record → start → record (mock
/// location stream) → stop → save → history → preview drive lands in **Spec 5B/6**,
/// once the device-only seams exist: the real `geolocator` background stream and
/// the granted location/notification permissions. Until then those steps cannot
/// be exercised faithfully through the real UI — they are covered headlessly by
/// the e2e test over the testable seams.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the app boots to its first screen on a device', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = PreferencesRepository(await SharedPreferences.getInstance());
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final previewDir = await Directory.systemTemp.createTemp('itest_preview');
    addTearDown(() => previewDir.delete(recursive: true));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesRepositoryProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(db),
          previewCacheDirProvider.overrideWithValue(previewDir),
        ],
        child: const RetrailApp(),
      ),
    );
    await tester.pump();

    // The app launches without crashing into its routed first screen.
    expect(find.byType(RetrailApp), findsOneWidget);
  });
}
