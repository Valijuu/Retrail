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
import 'package:retrail/features/shell/main_shell.dart';
import 'package:retrail/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/home_test_helpers.dart';

Future<Widget> _app(WidgetTester tester) async {
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
      ...homeStreamStubs(),
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
}
