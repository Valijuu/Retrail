import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens an external maps app navigating to a coordinate. Real impl uses a
/// universal `geo:` URI (chooser across installed maps apps); device-verified.
/// Interface seam → fakeable in tests.
abstract interface class NavigationLauncher {
  Future<void> launchTo(double lat, double lng, String label);
}

class GeoNavigationLauncher implements NavigationLauncher {
  const GeoNavigationLauncher();

  @override
  Future<void> launchTo(double lat, double lng, String label) async {
    final uri = Uri.parse(
        'geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(label)})');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

final navigationLauncherProvider =
    Provider<NavigationLauncher>((ref) => const GeoNavigationLauncher());
