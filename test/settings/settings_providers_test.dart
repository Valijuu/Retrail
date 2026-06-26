import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/features/settings/settings_providers.dart';

void main() {
  group('appLanguageFromTag', () {
    test('maps en/de and falls back to system', () {
      expect(appLanguageFromTag('en'), AppLanguage.english);
      expect(appLanguageFromTag('de'), AppLanguage.german);
      expect(appLanguageFromTag('system'), AppLanguage.system);
      expect(appLanguageFromTag('xx'), AppLanguage.system);
    });
  });

  group('tagFor', () {
    test('round-trips with appLanguageFromTag', () {
      for (final l in AppLanguage.values) {
        expect(appLanguageFromTag(tagFor(l)), l);
      }
    });
  });

  group('localeFor', () {
    test('system → null, english → en, german → de', () {
      expect(localeFor(AppLanguage.system), isNull);
      expect(localeFor(AppLanguage.english), const Locale('en'));
      expect(localeFor(AppLanguage.german), const Locale('de'));
    });
  });
}
