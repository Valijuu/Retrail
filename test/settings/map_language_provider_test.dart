import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/features/active_ride/active_ride_providers.dart';
import 'package:retrail/features/settings/settings_providers.dart';

void main() {
  test('the map language follows the app language (#128)', () {
    final c = ProviderContainer(
      overrides: [localeProvider.overrideWithValue(const Locale('de'))],
    );
    addTearDown(c.dispose);
    expect(c.read(mapLanguageProvider), 'de');
  });

  test('the previews of another language come from another cache (#128)', () {
    final dir = Directory.systemTemp.createTempSync('lang_previews');
    addTearDown(() => dir.deleteSync(recursive: true));
    final locale = ValueNotifier<Locale>(const Locale('en'));
    final c = ProviderContainer(
      overrides: [
        previewCacheDirProvider.overrideWithValue(dir),
        effectiveLocaleProvider.overrideWith((ref) => locale.value),
      ],
    );
    addTearDown(c.dispose);
    expect(c.read(routePreviewCacheProvider).language, 'en');
    locale.value = const Locale('de');
    c.invalidate(effectiveLocaleProvider);
    expect(c.read(routePreviewCacheProvider).language, 'de');
  });
}
