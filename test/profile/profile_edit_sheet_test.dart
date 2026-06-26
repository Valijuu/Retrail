import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:retrail/features/profile/profile_edit_sheet.dart';
import 'package:retrail/features/profile/profile_providers.dart';
import 'package:retrail/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late PreferencesRepository prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'user_name': 'Alex'});
    prefs = PreferencesRepository(await SharedPreferences.getInstance());
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        preferencesRepositoryProvider.overrideWithValue(prefs),
        currentProfilePhotoProvider.overrideWith((ref) => Stream.value(null)),
        recentProfilePhotosProvider.overrideWith((ref) => Stream.value(const [])),
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
        home: const Scaffold(body: ProfileEditSheet()),
      ),
    ));
    await tester.pump();
  }

  testWidgets('renders the title and the name seeded from prefs',
      (tester) async {
    await pump(tester);
    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget); // seeded name
  });

  testWidgets('Save writes the edited name', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'Robin');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(await prefs.userName.first, 'Robin');
  });

  testWidgets('Cancel does not change the name', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'Robin');
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(prefs.userNameNow, 'Alex');
  });
}
