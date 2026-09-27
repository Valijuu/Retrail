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

  // Both apps only parse the `scheme://?…` form with a literal comma —
  // `comgooglemaps:?q=52.5%2C13.4` opens the app but ignores the point.
  test('Google Maps: a route to the point, ready to start', () {
    final uri =
        navigationUri(NavigationApp.googleMaps, 52.5, 13.4, 'Morning roll');
    expect(uri.toString(), 'comgooglemaps://?daddr=52.5,13.4');
  });

  test('Waze: navigation to the point', () {
    final uri = navigationUri(NavigationApp.waze, 52.5, 13.4, 'Morning roll');
    expect(uri.toString(), 'waze://?ll=52.5,13.4&navigate=yes');
  });
}
