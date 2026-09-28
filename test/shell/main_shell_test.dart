import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/connectivity/connectivity_providers.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:retrail/features/profile/profile_avatar.dart';
import 'package:retrail/features/profile/profile_edit_sheet.dart';
import 'package:retrail/features/profile/profile_providers.dart';
import 'package:retrail/domain/ride_stats.dart';
import 'package:retrail/features/active_ride/active_ride_providers.dart';
import 'package:retrail/features/history/history_items.dart';
import 'package:retrail/features/history/history_ride_card.dart';
import 'package:retrail/features/home/top_header.dart';
import 'package:retrail/features/shell/main_shell.dart';
import 'package:retrail/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/home_test_helpers.dart';

Future<Widget> _app(WidgetTester tester,
    {List<HistoryItem> historyItems = const []}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = PreferencesRepository(await SharedPreferences.getInstance());
  final db = AppDatabase.memory();
  addTearDown(db.close);
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      preferencesRepositoryProvider.overrideWithValue(prefs),
      isOnlineProvider.overrideWith((ref) => Stream.value(true)),
      currentProfilePhotoProvider.overrideWith((ref) => Stream.value(null)),
      recentProfilePhotosProvider.overrideWith((ref) => Stream.value(const [])),
      previewCacheDirProvider.overrideWithValue(Directory.systemTemp),
      ...homeStreamStubs(history: historyItems),
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
      home: const MainShell(),
    ),
  );
}

void main() {
  testWidgets('renders three tabs', (tester) async {
    await tester.pumpWidget(await _app(tester));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('tapping a tab switches the page body', (tester) async {
    await tester.pumpWidget(await _app(tester));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('History'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // The real history screen renders its title (History tab body).
    expect(find.text('Ride history'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // The real settings screen renders its sections (e.g. the THEME header).
    expect(find.text('THEME'), findsOneWidget);
  });

  testWidgets('tapping the Home avatar opens the profile edit sheet',
      (tester) async {
    await tester.pumpWidget(await _app(tester));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The sheet is not present until the avatar is tapped.
    expect(find.byType(ProfileEditSheet), findsNothing);

    // The Home top-header avatar is the only ProfileAvatar on screen.
    await tester.tap(find.byType(ProfileAvatar));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ProfileEditSheet), findsOneWidget);
    expect(find.text('Edit profile'), findsOneWidget);
  });

  testWidgets('the profile sheet has a drag handle and closes when dragged down',
      (tester) async {
    await tester.pumpWidget(await _app(tester));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byType(ProfileAvatar));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.widget<BottomSheet>(find.byType(BottomSheet)).showDragHandle,
        isTrue);
    await tester.drag(find.text('Edit profile'), const Offset(0, 600));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ProfileEditSheet), findsNothing);
    // iOS too: while the content fits, even bouncing physics claim no drag.
  }, variant: const TargetPlatformVariant(
      {TargetPlatform.android, TargetPlatform.iOS}));

  testWidgets(
      'with the keyboard up the profile sheet stays capped below the top — '
      'it never grows to the screen edge', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: 350);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(await _app(tester));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byType(ProfileAvatar));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // A clear strip stays free above the sheet (drag handle included).
    expect(tester.getTopLeft(find.byType(BottomSheet)).dy,
        greaterThanOrEqualTo(900 * 0.08));
  });

  testWidgets(
      'on a tall phone the profile sheet hugs its content — Save sits at the '
      'bottom, no empty band below the buttons', (tester) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(await _app(tester));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byType(ProfileAvatar));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Only the content's own bottom spacing is left below Save, whatever the
    // screen height — not the rest of a fixed 90 %-tall sheet.
    final save = find.widgetWithText(FilledButton, 'Save');
    expect(1000 - tester.getBottomLeft(save).dy, lessThanOrEqualTo(24));
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets(
      'system back on a non-Home tab returns to Home instead of closing the '
      'app (issue #32)', (tester) async {
    await tester.pumpWidget(await _app(tester));
    await settle(tester);
    await tester.tap(find.text('Settings'));
    await settle(tester);
    expect(find.text('THEME'), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue); // consumed
    await settle(tester);
    expect(find.text('Recent rides'), findsOneWidget);
    expect(find.text('THEME'), findsNothing);
  });

  testWidgets(
      'system back retraces the visited tabs: Settings → History → Home',
      (tester) async {
    await tester.pumpWidget(await _app(tester));
    await settle(tester);
    await tester.tap(find.text('History'));
    await settle(tester);
    await tester.tap(find.text('Settings'));
    await settle(tester);
    expect(find.text('THEME'), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await settle(tester);
    expect(find.text('Ride history'), findsOneWidget); // back on History

    expect(await tester.binding.handlePopRoute(), isTrue);
    await settle(tester);
    expect(find.text('Recent rides'), findsOneWidget); // then Home
  });

  testWidgets(
      'revisiting a tab moves it to the top of the back history instead of '
      'stacking duplicates', (tester) async {
    await tester.pumpWidget(await _app(tester));
    await settle(tester);
    await tester.tap(find.text('History'));
    await settle(tester);
    await tester.tap(find.text('Settings'));
    await settle(tester);
    await tester.tap(find.text('History'));
    await settle(tester);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await settle(tester);
    expect(find.text('THEME'), findsOneWidget); // Settings, not History again

    expect(await tester.binding.handlePopRoute(), isTrue);
    await settle(tester);
    expect(find.text('Recent rides'), findsOneWidget);
  });

  testWidgets(
      'system back in History selection mode only exits the selection '
      '(issue #32)', (tester) async {
    final ride = RideEntryItem(
      const Ride(
        rideId: 1,
        description: 'Evening roll',
        typ: null,
        startTime: 0,
        endTime: 600000,
        date: 1718193600000,
        comment: null,
        isFavorite: false,
        favoritedAt: null,
        hasRoute: false,
      ),
      const RideStats(
          durationMs: 600000,
          distanceMetres: 1000,
          maxSpeedKmh: 10,
          avgSpeedKmh: 6),
    );
    await tester.pumpWidget(await _app(tester, historyItems: [ride]));
    await settle(tester);
    await tester.tap(find.text('History'));
    await settle(tester);
    await settle(tester); // items stream resumes once the tab is visible
    await tester.longPress(find.byType(HistoryRideCard));
    await settle(tester);
    expect(find.text('1 selected'), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await settle(tester);
    expect(find.text('1 selected'), findsNothing);
    expect(find.text('Ride history'), findsOneWidget); // still on History

    expect(await tester.binding.handlePopRoute(), isTrue);
    await settle(tester);
    expect(find.text('Recent rides'), findsOneWidget); // now back on Home
  });

  testWidgets(
      'the greeting stays put while leaving and returning to Home, and '
      're-rolls once on arrival', (tester) async {
    await tester.pumpWidget(await _app(tester));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // The greeting as rendered — not HomeScreen's prop — so state re-rolling
    // inside Home would be caught too.
    String shown() => tester
        .widget<RichText>(find
            .descendant(
                of: find.byType(TopHeader), matching: find.byType(RichText))
            .first)
        .text
        .toPlainText();
    final before = shown();

    await tester.tap(find.text('History'));
    await tester.pump(const Duration(milliseconds: 100)); // Home sliding out
    expect(shown(), before);
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Home'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150)); // Home sliding in
    expect(shown(), before); // still the text the user left
    await tester.pump(const Duration(milliseconds: 400));
    final arrived = shown();
    expect(arrived, isNot(before)); // re-rolled on arrival…
    await tester.pump(const Duration(milliseconds: 400));
    expect(shown(), arrived); // …and only once
  });
}
