import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/data_providers.dart';

/// Maps the stored theme-mode string to a Flutter [ThemeMode].
ThemeMode themeModeFromString(String value) => switch (value) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };

/// The user's selected theme mode (system/light/dark) as a [ThemeMode].
final themeModeProvider = StreamProvider<ThemeMode>(
  (ref) => ref
      .watch(preferencesRepositoryProvider)
      .themeMode
      .map(themeModeFromString),
);
