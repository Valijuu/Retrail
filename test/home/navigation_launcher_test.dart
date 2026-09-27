import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/features/home/navigation_launcher.dart';

void main() {
  test('system: a geo: URI so Android offers its maps-app chooser', () {
    final uri = navigationUri(NavigationApp.system, 52.5, 13.4, 'Morning roll');
    expect(uri.toString(), 'geo:52.5,13.4?q=52.5,13.4(Morning%20roll)');
  });

  test('Apple Maps: a maps.apple.com link pinning the labelled point', () {
    final uri =
        navigationUri(NavigationApp.appleMaps, 52.5, 13.4, 'Morning roll');
    expect(uri.scheme, 'https');
    expect(uri.host, 'maps.apple.com');
    expect(uri.queryParameters['ll'], '52.5,13.4');
    expect(uri.queryParameters['q'], 'Morning roll');
  });

  test('Google Maps: the comgooglemaps: scheme pinning the point', () {
    final uri =
        navigationUri(NavigationApp.googleMaps, 52.5, 13.4, 'Morning roll');
    expect(uri.scheme, 'comgooglemaps');
    expect(uri.queryParameters['q'], '52.5,13.4');
  });

  test('Waze: the waze: scheme navigating to the point', () {
    final uri = navigationUri(NavigationApp.waze, 52.5, 13.4, 'Morning roll');
    expect(uri.scheme, 'waze');
    expect(uri.queryParameters['ll'], '52.5,13.4');
    expect(uri.queryParameters['navigate'], 'yes');
  });
}
