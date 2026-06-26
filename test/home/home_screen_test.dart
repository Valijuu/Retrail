import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/app.dart';
import 'package:retrail/core/connectivity/connectivity_providers.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/domain/stats_aggregation.dart';
import 'package:retrail/features/home/recent_ride_ui.dart';
import 'package:retrail/tracking/tracking_providers.dart';

import 'home_test_helpers.dart';

/// Bounded settle — HomeScreen's stream providers stay subscribed, so
/// `pumpAndSettle` never returns; pump a fixed window instead.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  Future<void> pumpHome(
    WidgetTester tester, {
    bool tracking = false,
    List<RecentRideUi> recent = const [],
    List<RecentRideUi> favorites = const [],
    WeeklyStats weekly = const WeeklyStats.zero(),
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final env = await buildHomeEnv(initialPrefs: {'onboarding_done': true});
    addTearDown(env.db.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(env.db),
        preferencesRepositoryProvider.overrideWithValue(env.prefs),
        isOnlineProvider.overrideWith((ref) => Stream.value(true)),
        if (tracking) isTrackingProvider.overrideWithValue(true),
        ...activeRideTestOverrides(env.db),
        ...homeStreamStubs(
            recent: recent, favorites: favorites, weekly: weekly),
      ],
      child: const RetrailApp(),
    ));
    await _settle(tester);
  }

  testWidgets('renders sections with empty placeholders', (tester) async {
    await pumpHome(tester);
    expect(find.text('Recent rides'), findsOneWidget);
    expect(find.text('No rides yet — time to roll.'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('No favorites yet.'), findsOneWidget);
  });

  testWidgets('renders ride cards and hero stats from populated data',
      (tester) async {
    await pumpHome(
      tester,
      recent: const [
        RecentRideUi(
          rideId: 1,
          title: 'Morning roll',
          dateTime: 'Today, 08:00',
          distanceKm: 4.2,
          hasRoute: true,
        ),
      ],
      weekly: const WeeklyStats(
        totalKm: 12.5,
        rideCount: 3,
        avgSpeedKmh: 0,
        totalDurationSeconds: 0,
      ),
    );
    expect(find.text('Morning roll'), findsOneWidget);
    expect(find.text('4.2 km'), findsOneWidget); // ride-card distance
    expect(find.text('12.5 km'), findsOneWidget); // weekly hero distance
  });

  testWidgets('Start tracking routes to the countdown timer', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('Start tracking'));
    await _settle(tester);
    expect(find.text('GET READY'), findsOneWidget);
  });

  testWidgets('reopens the active ride when already tracking', (tester) async {
    await pumpHome(tester, tracking: true);
    await tester.tap(find.text('Start tracking'));
    await _settle(tester);
    expect(find.text('Retrail ride'), findsOneWidget);
  });
}
