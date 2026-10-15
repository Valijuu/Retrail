import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/db/ride_dao.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:retrail/data/repositories/ride_repository.dart';
import 'package:retrail/features/history/edit_ride_sheet.dart';
import 'package:retrail/features/shell/ride_saved_notice.dart';
import 'package:retrail/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _ride = Ride(
  rideId: 5,
  description: 'Evening roll',
  typ: null,
  startTime: 0,
  endTime: 600000,
  date: 0,
  comment: null,
  isFavorite: false,
  favoritedAt: null,
  hasRoute: false,
);

class _FakeNoticeController implements RideSavedNoticeController {
  _FakeNoticeController(this.ride);
  Ride? ride;
  int takes = 0;
  @override
  Future<Ride?> take() async {
    takes++;
    final r = ride;
    ride = null;
    return r;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Issue #75: a ride stopped from the notification is saved silently; the
  // next time the app is in front, the rider is told and can add details.
  group('RideSavedNoticeController.take', () {
    late AppDatabase db;
    late PreferencesRepository prefs;
    late RideSavedNoticeController controller;

    setUp(() async {
      db = AppDatabase.memory();
      SharedPreferences.setMockInitialValues({});
      prefs = PreferencesRepository(await SharedPreferences.getInstance());
      controller = RideSavedNoticeController(
        prefs,
        RideRepository(RideDao(db)),
      );
    });
    tearDown(() => db.close());

    test('returns the parked ride once and clears it', () async {
      final id = await RideRepository(RideDao(db)).startRide(startedAtMs: 1000);
      await prefs.setPendingRideDetails(id);
      expect((await controller.take())!.rideId, id);
      expect(prefs.pendingRideDetailsNow, isNull);
      expect(await controller.take(), isNull);
    });

    test(
      'a parked ride that no longer exists yields null and is cleared',
      () async {
        await prefs.setPendingRideDetails(99);
        expect(await controller.take(), isNull);
        expect(prefs.pendingRideDetailsNow, isNull);
      },
    );
  });

  group('RideSavedNotice', () {
    Future<_FakeNoticeController> pump(WidgetTester tester, Ride? ride) async {
      final fake = _FakeNoticeController(ride);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rideSavedNoticeControllerProvider.overrideWithValue(fake),
            pendingRideDetailsProvider.overrideWith(
              (ref) => Stream.value(null),
            ),
          ],
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: RideSavedNotice(child: SizedBox())),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      return fake;
    }

    testWidgets('shows "Ride saved" once with an Add details action', (
      tester,
    ) async {
      await pump(tester, _ride);
      expect(find.text('Ride saved'), findsOneWidget);
      expect(find.text('Add details'), findsOneWidget);
    });

    testWidgets('Add details opens the edit sheet for that ride', (
      tester,
    ) async {
      await pump(tester, _ride);
      await tester.pumpAndSettle(); // let the snack bar slide in first
      await tester.tap(find.text('Add details'));
      await tester.pumpAndSettle();
      expect(find.byType(EditRideSheet), findsOneWidget);
      expect(find.text('Evening roll'), findsOneWidget);
    });

    testWidgets('closes on its own after a few seconds', (tester) async {
      await pump(tester, _ride);
      await tester.pumpAndSettle();
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.persist, isFalse);
      expect(bar.duration, const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Ride saved'), findsNothing);
    });

    testWidgets('the close icon dismisses it', (tester) async {
      await pump(tester, _ride);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('Ride saved'), findsNothing);
    });

    testWidgets('nothing parked → no snack bar', (tester) async {
      await pump(tester, null);
      expect(find.text('Ride saved'), findsNothing);
    });

    testWidgets('waits while the app is in the background', (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final fake = await pump(tester, _ride);
      expect(find.text('Ride saved'), findsNothing);
      expect(fake.takes, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(find.text('Ride saved'), findsOneWidget);
    });
  });
}
