import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/l10n/app_localizations.dart';

void main() {
  group('AppLocalizations', () {
    test('supports English and German', () {
      expect(AppLocalizations.supportedLocales, contains(const Locale('en')));
      expect(AppLocalizations.supportedLocales, contains(const Locale('de')));
    });

    test('resolves appTitle to "Retrail" in English', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(l10n.appTitle, 'Retrail');
    });

    test('resolves appTitle to "Retrail" in German', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('de'));
      expect(l10n.appTitle, 'Retrail');
    });
  });
}
