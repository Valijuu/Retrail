import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/features/home/greetings.dart';
import 'package:retrail/l10n/app_localizations.dart';

void main() {
  test('German greetings are the chosen skater set', () {
    expect(skaterGreetings(lookupAppLocalizations(const Locale('de'))), [
      "Bock auf 'ne Session, %s?",
      "Los geht's, %s!",
      'Kopf frei, Strecke frei, %s',
      'Ganz easy heute, %s',
      'Kilometer sammeln, %s?',
      'Neuer Tag, neuer Flow, %s',
      'Ready für die nächste Runde, %s?',
      'Wohin cruist du heute, %s?',
    ]);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    test('$locale: count matches skaterGreetingCount, one name slot each', () {
      final greetings = skaterGreetings(lookupAppLocalizations(locale));
      expect(greetings, hasLength(skaterGreetingCount));
      for (final g in greetings) {
        expect('%s'.allMatches(g), hasLength(1), reason: g);
      }
    });
  }
}
