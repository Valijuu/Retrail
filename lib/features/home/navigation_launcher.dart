import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// A maps app the navigate-to-start button can hand a coordinate to.
/// [system] is Android's `geo:` intent, where the OS itself shows a chooser
/// across installed maps apps. iOS has no such chooser, so there each app is
/// offered by name (see `navigateTo`).
enum NavigationApp { system, appleMaps, googleMaps, waze }

/// Deep link that opens [app] at the labelled coordinate.
Uri navigationUri(NavigationApp app, double lat, double lng, String label) =>
    switch (app) {
      NavigationApp.system => Uri.parse(
          'geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(label)})'),
      NavigationApp.appleMaps =>
        Uri.https('maps.apple.com', '/', {'ll': '$lat,$lng', 'q': label}),
      // Parsed from a literal string: both apps ignore the point unless it is
      // the `scheme://?…` form with an unencoded comma, which Uri() won't emit.
      NavigationApp.googleMaps => Uri.parse('comgooglemaps://?daddr=$lat,$lng'),
      NavigationApp.waze => Uri.parse('waze://?ll=$lat,$lng&navigate=yes'),
    };

/// Opens an external maps app navigating to a coordinate. Interface seam →
/// fakeable in tests.
abstract interface class NavigationLauncher {
  /// Installed apps to offer, in display order (never empty).
  Future<List<NavigationApp>> availableApps();

  Future<void> launch(NavigationApp app, double lat, double lng, String label);
}

class UrlNavigationLauncher implements NavigationLauncher {
  const UrlNavigationLauncher();

  /// Third-party iOS apps probed by URL scheme. Each scheme must be listed
  /// under `LSApplicationQueriesSchemes` in ios/Runner/Info.plist, or
  /// `canLaunchUrl` always reports it missing.
  static const _iosThirdParty = {
    NavigationApp.googleMaps: 'comgooglemaps://',
    NavigationApp.waze: 'waze://',
  };

  @override
  Future<List<NavigationApp>> availableApps() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const [NavigationApp.system];
    }
    return [
      NavigationApp.appleMaps,
      for (final MapEntry(key: app, value: scheme) in _iosThirdParty.entries)
        if (await canLaunchUrl(Uri.parse(scheme))) app,
    ];
  }

  @override
  Future<void> launch(
      NavigationApp app, double lat, double lng, String label) async {
    await launchUrl(navigationUri(app, lat, lng, label),
        mode: LaunchMode.externalApplication);
  }
}

final navigationLauncherProvider =
    Provider<NavigationLauncher>((ref) => const UrlNavigationLauncher());
