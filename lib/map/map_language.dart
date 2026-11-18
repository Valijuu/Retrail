import 'dart:ui' show Locale;

/// The language of the place names on the map (#128): `de` for German, `en` for
/// everything else, as OpenMapTiles carries `name_de` and `name_en` fields.
String mapLanguageFor(Locale locale) =>
    locale.languageCode == 'de' ? 'de' : 'en';
