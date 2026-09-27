import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens an external maps app navigating to a coordinate. Interface seam →
/// fakeable in tests.
abstract interface class NavigationLauncher {
  Future<void> launchTo(double lat, double lng, String label);
}

/// Android: a universal `geo:` URI (system chooser across installed maps
/// apps). iOS has no `geo:` handler, so it gets an Apple Maps link instead.
Uri navigationUri(
    double lat, double lng, String label, TargetPlatform platform) {
  if (platform == TargetPlatform.iOS) {
    return Uri.https('maps.apple.com', '/', {'ll': '$lat,$lng', 'q': label});
  }
  return Uri.parse('geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(label)})');
}

class GeoNavigationLauncher implements NavigationLauncher {
  const GeoNavigationLauncher();

  @override
  Future<void> launchTo(double lat, double lng, String label) async {
    await launchUrl(navigationUri(lat, lng, label, defaultTargetPlatform),
        mode: LaunchMode.externalApplication);
  }
}

final navigationLauncherProvider =
    Provider<NavigationLauncher>((ref) => const GeoNavigationLauncher());
