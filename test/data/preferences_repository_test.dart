import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PreferencesRepository> build([
    Map<String, Object> initial = const {},
  ]) async {
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

  test(
    'home stats period defaults to the week and persists a choice',
    () async {
      final prefs = await build();
      expect(await prefs.homeStatsPeriod.first, 'week');
      await prefs.setHomeStatsPeriod('year');
      expect(await prefs.homeStatsPeriod.first, 'year');
    },
  );

  test('history view and map mode default and persist a choice', () async {
    final prefs = await build();
    expect(await prefs.historyView.first, 'list');
    expect(await prefs.historyMapMode.first, 'lines');
    await prefs.setHistoryView('map');
    await prefs.setHistoryMapMode('heat');
    expect(await prefs.historyView.first, 'map');
    expect(await prefs.historyMapMode.first, 'heat');
  });

  // Issue #75: a ride stopped from the notification waits here for the
  // in-app "Ride saved" hint — across a process restart.
  test('pending ride details persist until cleared', () async {
    final prefs = await build();
    expect(prefs.pendingRideDetailsNow, isNull);
    await prefs.setPendingRideDetails(7);
    expect(prefs.pendingRideDetailsNow, 7);
    final reopened = PreferencesRepository(
      await SharedPreferences.getInstance(),
    );
    expect(reopened.pendingRideDetailsNow, 7);
    await prefs.setPendingRideDetails(null);
    expect(prefs.pendingRideDetailsNow, isNull);
  });

  test('pending ride details stream re-emits on write', () async {
    final prefs = await build();
    final future = prefs.pendingRideDetails.take(2).toList();
    await Future<void>.delayed(Duration.zero);
    await prefs.setPendingRideDetails(3);
    expect(await future, [null, 3]);
  });

  group('countdown cue switch (#81)', () {
    test('is on by default', () async {
      final prefs = await build();
      expect(await prefs.countdownCueEnabled.first, isTrue);
      expect(prefs.countdownCueEnabledNow, isTrue);
    });

    test('persists off and re-emits', () async {
      final prefs = await build();
      final future = prefs.countdownCueEnabled.take(2).toList();
      await Future<void>.delayed(Duration.zero);
      await prefs.setCountdownCueEnabled(false);
      expect(await future, [true, false]);
      expect(prefs.countdownCueEnabledNow, isFalse);
    });
  });

  // Issue #134: on iOS the app container path changes with an update, so a
  // stored absolute photo path pointed nowhere and the avatar went black.
  group('profile photo paths (#134)', () {
    const root = '/var/new/Documents';

    Future<PreferencesRepository> withRoot([
      Map<String, Object> initial = const {},
    ]) async {
      SharedPreferences.setMockInitialValues(initial);
      return PreferencesRepository(
        await SharedPreferences.getInstance(),
        photoRoot: root,
      );
    }

    test('an absolute path from an older container is re-rooted', () async {
      final prefs = await withRoot({
        'current_profile_photo': '/var/old/Documents/profile_photos/1.jpg',
        'profile_photos':
            '["/var/old/Documents/profile_photos/1.jpg",'
            '"/var/old/Documents/profile_photos/2.jpg"]',
      });
      expect(prefs.currentProfilePhotoNow, '$root/profile_photos/1.jpg');
      expect(prefs.recentProfilePhotosNow, [
        '$root/profile_photos/1.jpg',
        '$root/profile_photos/2.jpg',
      ]);
    });

    test('a path inside the root is stored relative and read back '
        'absolute', () async {
      final prefs = await withRoot();
      await prefs.setCurrentProfilePhoto('$root/profile_photos/3.jpg');
      await prefs.setRecentProfilePhotos(['$root/profile_photos/3.jpg']);
      final raw = await SharedPreferences.getInstance();
      expect(raw.getString('current_profile_photo'), 'profile_photos/3.jpg');
      expect(raw.getString('profile_photos'), '["profile_photos/3.jpg"]');
      expect(prefs.currentProfilePhotoNow, '$root/profile_photos/3.jpg');
      expect(prefs.recentProfilePhotosNow, ['$root/profile_photos/3.jpg']);
    });

    test('a path that is not a profile photo stays as it is', () async {
      final prefs = await withRoot({
        'current_profile_photo': '/elsewhere/a.jpg',
      });
      expect(prefs.currentProfilePhotoNow, '/elsewhere/a.jpg');
    });

    test('without a root the paths are unchanged', () async {
      final prefs = await build();
      await prefs.setCurrentProfilePhoto('/a/profile_photos/1.jpg');
      expect(prefs.currentProfilePhotoNow, '/a/profile_photos/1.jpg');
    });
  });
}
