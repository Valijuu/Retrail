import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Local profile/settings store backed by [SharedPreferences], replacing the
/// original DataStore. Exposes reactive `Stream`s (seed current value, then
/// re-emit on any write) — mirroring the Kotlin `Flow` getters.
class PreferencesRepository {
  PreferencesRepository(this._prefs);

  final SharedPreferences _prefs;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  // Keys & defaults — identical to the original UserPreferencesRepository.
  static const _kUserName = 'user_name';
  static const _kAvatarIndex = 'avatar_index';
  static const _kOnboardingDone = 'onboarding_done';
  static const _kCustomPhotoPath = 'custom_photo_path';
  static const _kThemeMode = 'theme_mode';
  static const _kLastActivityType = 'last_activity_type';

  static const defaultUserName = 'Retrailer';
  static const defaultAvatarIndex = 0;
  static const defaultThemeMode = 'system';
  static const defaultActivityType = 'LONGBOARD';

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    yield* _changes.stream.map((_) => read());
  }

  Stream<String> get userName =>
      _watch(() => _prefs.getString(_kUserName) ?? defaultUserName);

  Stream<int> get avatarIndex =>
      _watch(() => _prefs.getInt(_kAvatarIndex) ?? defaultAvatarIndex);

  Stream<bool> get onboardingDone =>
      _watch(() => _prefs.getBool(_kOnboardingDone) ?? false);

  Stream<String?> get customPhotoPath => _watch(() {
        final path = _prefs.getString(_kCustomPhotoPath);
        return (path != null && path.isNotEmpty) ? path : null;
      });

  Stream<String> get themeMode =>
      _watch(() => _prefs.getString(_kThemeMode) ?? defaultThemeMode);

  /// Last activity type chosen in the picker — preselection for the next ride.
  Stream<String> get lastActivityType =>
      _watch(() => _prefs.getString(_kLastActivityType) ?? defaultActivityType);

  Future<void> saveUserName(String name) async {
    await _prefs.setString(_kUserName, name);
    _notify();
  }

  Future<void> saveCustomPhotoPath(String path) async {
    await _prefs.setString(_kCustomPhotoPath, path);
    _notify();
  }

  Future<void> clearCustomPhoto() async {
    await _prefs.remove(_kCustomPhotoPath);
    _notify();
  }

  Future<void> saveAvatarIndex(int index) async {
    await _prefs.setInt(_kAvatarIndex, index);
    _notify();
  }

  Future<void> setOnboardingDone() async {
    await _prefs.setBool(_kOnboardingDone, true);
    _notify();
  }

  Future<void> setThemeMode(String mode) async {
    await _prefs.setString(_kThemeMode, mode);
    _notify();
  }

  Future<void> saveLastActivityType(String id) async {
    await _prefs.setString(_kLastActivityType, id);
    _notify();
  }

  void _notify() => _changes.add(null);

  void dispose() => _changes.close();
}
