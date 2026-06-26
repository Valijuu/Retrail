import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:retrail/domain/activity_type.dart';
import 'package:retrail/features/settings/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late PreferencesRepository prefs;
  late SettingsController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = PreferencesRepository(await SharedPreferences.getInstance());
    controller = SettingsController(prefs);
  });

  test('setTheme persists the theme mode string', () async {
    await controller.setTheme(ThemeMode.dark);
    expect(await prefs.themeMode.first, 'dark');
    await controller.setTheme(ThemeMode.system);
    expect(await prefs.themeMode.first, 'system');
  });

  test('setLanguage persists the language tag', () async {
    await controller.setLanguage(AppLanguage.german);
    expect(await prefs.language.first, 'de');
    await controller.setLanguage(AppLanguage.system);
    expect(await prefs.language.first, 'system');
  });

  test('setDefaultActivity persists the activity id', () async {
    await controller.setDefaultActivity(ActivityType.scooter);
    expect(await prefs.lastActivityType.first, 'SCOOTER');
  });
}
