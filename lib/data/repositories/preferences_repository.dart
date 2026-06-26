import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local profile/settings store backed by [SharedPreferences], replacing the
/// original DataStore. Exposes reactive `Stream`s (seed current value, then
/// re-emit on any write) — mirroring the Kotlin `Flow` getters.
class PreferencesRepository {
  PreferencesRepository(this._prefs);

  final SharedPreferences _prefs;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  static const _kUserName = 'user_name';
  static const _kOnboardingDone = 'onboarding_done';
  static const _kThemeMode = 'theme_mode';
  static const _kLanguage = 'app_language';
  static const _kLastActivityType = 'last_activity_type';
  static const _kCurrentPhoto = 'current_profile_photo';
  static const _kRecentPhotos = 'profile_photos';

  static const defaultUserName = 'Retrailer';
  static const defaultThemeMode = 'system';
  static const defaultLanguage = 'system';
  static const defaultActivityType = 'LONGBOARD';

  /// Max number of recent profile photos kept.
  static const maxRecentPhotos = 5;

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    yield* _changes.stream.map((_) => read());
  }

  Stream<String> get userName =>
      _watch(() => _prefs.getString(_kUserName) ?? defaultUserName);

  Stream<bool> get onboardingDone =>
      _watch(() => _prefs.getBool(_kOnboardingDone) ?? false);

  Stream<String> get themeMode =>
      _watch(() => _prefs.getString(_kThemeMode) ?? defaultThemeMode);

  /// App-interface language: `system` | `en` | `de`.
  Stream<String> get language =>
      _watch(() => _prefs.getString(_kLanguage) ?? defaultLanguage);

  /// Current user name synchronously (for seeding edit fields). Empty → blank.
  String get userNameNow => _prefs.getString(_kUserName) ?? '';

  /// Last activity type chosen in the picker — preselection for the next ride.
  Stream<String> get lastActivityType =>
      _watch(() => _prefs.getString(_kLastActivityType) ?? defaultActivityType);

  // ── Profile photo ────────────────────────────────────────────────────────

  String? _readCurrentPhoto() {
    final path = _prefs.getString(_kCurrentPhoto);
    return (path != null && path.isNotEmpty) ? path : null;
  }

  List<String> _readRecentPhotos() {
    final raw = _prefs.getString(_kRecentPhotos);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return const [];
    }
  }

  /// The selected profile photo path, or null when blank.
  Stream<String?> get currentProfilePhoto => _watch(_readCurrentPhoto);
  String? get currentProfilePhotoNow => _readCurrentPhoto();

  /// Up to [maxRecentPhotos] recent photo paths, newest first.
  Stream<List<String>> get recentProfilePhotos => _watch(_readRecentPhotos);
  List<String> get recentProfilePhotosNow => _readRecentPhotos();

  Future<void> setCurrentProfilePhoto(String? path) async {
    if (path == null || path.isEmpty) {
      await _prefs.remove(_kCurrentPhoto);
    } else {
      await _prefs.setString(_kCurrentPhoto, path);
    }
    _notify();
  }

  Future<void> setRecentProfilePhotos(List<String> paths) async {
    await _prefs.setString(_kRecentPhotos, jsonEncode(paths));
    _notify();
  }

  // ── Writers ──────────────────────────────────────────────────────────────

  Future<void> saveUserName(String name) async {
    await _prefs.setString(_kUserName, name);
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

  Future<void> setLanguage(String tag) async {
    await _prefs.setString(_kLanguage, tag);
    _notify();
  }

  Future<void> saveLastActivityType(String id) async {
    await _prefs.setString(_kLastActivityType, id);
    _notify();
  }

  void _notify() => _changes.add(null);

  void dispose() => _changes.close();
}
