import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/map/map_language.dart';

void main() {
  group('mapLanguageFor (#128)', () {
    test('German, with or without a country, is de', () {
      expect(mapLanguageFor(const Locale('de')), 'de');
      expect(mapLanguageFor(const Locale('de', 'AT')), 'de');
    });

    test('English and every other language is en', () {
      expect(mapLanguageFor(const Locale('en')), 'en');
      expect(mapLanguageFor(const Locale('fr')), 'en');
    });
  });
}
