import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/data_providers.dart';
import '../../data/repositories/preferences_repository.dart';
import '../../domain/activity_type.dart';

/// App-interface language. `system` follows the device locale; the others force
/// an override. Mirrors the original `AppLocale`, but Flutter applies it in-app.
enum AppLanguage { system, english, german }

/// Maps a stored language tag to [AppLanguage] (`en`→english, `de`→german).
AppLanguage appLanguageFromTag(String tag) => switch (tag) {
      'en' => AppLanguage.english,
      'de' => AppLanguage.german,
      _ => AppLanguage.system,
    };

/// The stored tag for a language (system → 'system').
String tagFor(AppLanguage language) => switch (language) {
      AppLanguage.english => 'en',
      AppLanguage.german => 'de',
      AppLanguage.system => 'system',
    };

/// The [Locale] override for a language; null = follow the system locale.
Locale? localeFor(AppLanguage language) => switch (language) {
      AppLanguage.english => const Locale('en'),
      AppLanguage.german => const Locale('de'),
      AppLanguage.system => null,
    };

/// The user's selected interface language.
final appLanguageProvider = StreamProvider<AppLanguage>(
  (ref) => ref
      .watch(preferencesRepositoryProvider)
      .language
      .map(appLanguageFromTag),
);

/// The active [Locale] override for `MaterialApp` (null = system). Unknown
/// (loading) is treated as system.
final localeProvider = Provider<Locale?>(
  (ref) => localeFor(
      ref.watch(appLanguageProvider).asData?.value ?? AppLanguage.system),
);

/// Thin testable seam over the preference writers (mirrors `SettingsViewModel`).
/// DataStore stays the single source of truth — the screen reads the live
/// providers and the controller only writes back.
class SettingsController {
  SettingsController(this._prefs);

  final PreferencesRepository _prefs;

  Future<void> setTheme(ThemeMode mode) => _prefs.setThemeMode(switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      });

  Future<void> setLanguage(AppLanguage language) =>
      _prefs.setLanguage(tagFor(language));

  Future<void> setDefaultActivity(ActivityType type) =>
      _prefs.saveLastActivityType(type.id);
}

final settingsControllerProvider = Provider<SettingsController>(
  (ref) => SettingsController(ref.watch(preferencesRepositoryProvider)),
);
