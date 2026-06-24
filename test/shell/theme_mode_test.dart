import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/features/shell/theme_mode_provider.dart';

void main() {
  test('maps stored strings to ThemeMode', () {
    expect(themeModeFromString('dark'), ThemeMode.dark);
    expect(themeModeFromString('light'), ThemeMode.light);
    expect(themeModeFromString('system'), ThemeMode.system);
    expect(themeModeFromString('anything-else'), ThemeMode.system);
  });
}
