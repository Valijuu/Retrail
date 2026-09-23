import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PreferencesRepository> build([Map<String, Object> initial = const {}]) async {
    SharedPreferences.setMockInitialValues(initial);
    return PreferencesRepository(await SharedPreferences.getInstance());
  }

  test('exposes the original defaults when unset', () async {
    final prefs = await build();
    expect(await prefs.userName.first, 'Retrailer');
    expect(await prefs.onboardingDone.first, false);
    expect(await prefs.themeMode.first, 'system');
    expect(await prefs.lastActivityType.first, 'LONGBOARD');
    expect(await prefs.currentProfilePhoto.first, isNull);
    expect(await prefs.recentProfilePhotos.first, isEmpty);
  });

  test('persists written values', () async {
    final prefs = await build();
    await prefs.saveUserName('Vali');
    await prefs.setOnboardingDone();
    await prefs.setThemeMode('dark');
    await prefs.saveLastActivityType('SKATEBOARD');

    expect(await prefs.userName.first, 'Vali');
    expect(await prefs.onboardingDone.first, true);
    expect(await prefs.themeMode.first, 'dark');
    expect(await prefs.lastActivityType.first, 'SKATEBOARD');
  });

  test('streams re-emit on write', () async {
    final prefs = await build();
    final future = prefs.themeMode.take(2).toList();
    await Future<void>.delayed(Duration.zero);
    await prefs.setThemeMode('light');
    expect(await future, ['system', 'light']);
  });

  test('home stats period defaults to the week and persists a choice', () async {
    final prefs = await build();
    expect(await prefs.homeStatsPeriod.first, 'week');
    await prefs.setHomeStatsPeriod('year');
    expect(await prefs.homeStatsPeriod.first, 'year');
  });
}
