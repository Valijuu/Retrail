import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/features/home/navigation_launcher.dart';

void main() {
  test('Android uses a geo: URI so the system offers a maps-app chooser', () {
    final uri = navigationUri(52.5, 13.4, 'Morning roll', TargetPlatform.android);
    expect(uri.toString(), 'geo:52.5,13.4?q=52.5,13.4(Morning%20roll)');
  });

  test('iOS uses an Apple Maps link — iOS has no geo: handler', () {
    final uri = navigationUri(52.5, 13.4, 'Morning roll', TargetPlatform.iOS);
    expect(uri.scheme, 'https');
    expect(uri.host, 'maps.apple.com');
    expect(uri.queryParameters['ll'], '52.5,13.4');
    expect(uri.queryParameters['q'], 'Morning roll');
  });
}
