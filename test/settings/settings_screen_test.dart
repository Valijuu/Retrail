import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:retrail/domain/activity_type.dart';
import 'package:retrail/features/home/home_providers.dart';
import 'package:retrail/features/settings/settings_providers.dart';
import 'package:retrail/features/settings/settings_screen.dart';
import 'package:retrail/features/shell/theme_mode_provider.dart';
import 'package:retrail/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSettingsController extends SettingsController {
  FakeSettingsController(super.prefs);
  final calls = <String>[];
  @override
  Future<void> setTheme(ThemeMode m) async => calls.add('theme:${m.name}');
  @override
  Future<void> setLanguage(AppLanguage l) async => calls.add('lang:${l.name}');
  @override
  Future<void> setDefaultActivity(ActivityType t) async =>
      calls.add('activity:${t.id}');
}

void main() {
  late FakeSettingsController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    controller =
        FakeSettingsController(PreferencesRepository(await SharedPreferences.getInstance()));
  });

  Future<void> pump(
    WidgetTester tester, {
    ThemeMode theme = ThemeMode.system,
    AppLanguage language = AppLanguage.system,
    ActivityType activity = ActivityType.longboard,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        themeModeProvider.overrideWith((ref) => Stream.value(theme)),
        appLanguageProvider.overrideWith((ref) => Stream.value(language)),
        lastActivityTypeProvider.overrideWith((ref) => Stream.value(activity)),
        settingsControllerProvider.overrideWithValue(controller),
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
        home: const Scaffold(body: SettingsScreen()),
      ),
    ));
    await tester.pump();
  }

  testWidgets('renders the three sections and option rows', (tester) async {
    await pump(tester);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('LANGUAGE'), findsOneWidget);
    expect(find.text('THEME'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Deutsch'), findsOneWidget);
    // The default-activity summary row shows the current activity.
    expect(find.text('Longboard'), findsOneWidget);
  });

  testWidgets('tapping a theme row calls setTheme', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Dark'));
    expect(controller.calls, contains('theme:dark'));
  });

  testWidgets('tapping a language row calls setLanguage', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Deutsch'));
    expect(controller.calls, contains('lang:german'));
  });

  testWidgets('activity row opens the picker; choosing a tile saves it',
      (tester) async {
    await pump(tester);
    await tester.tap(find.text('Longboard'));
    await tester.pumpAndSettle();
    expect(find.text('Default activity'), findsOneWidget);
    await tester.tap(find.text('Scooter'));
    await tester.pumpAndSettle();
    expect(controller.calls, contains('activity:SCOOTER'));
  });
}
