import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/map/live_map.dart';

void main() {
  group('liveMapStyle', () {
    test('light mode hands MapLibre the bundled Retrail Light asset path', () {
      expect(liveMapStyle(false, 'en'), 'assets/map/retrail_light.json');
    });

    // MapLibre loads a Flutter asset path asynchronously, so the style loads
    // after onMapCreated. A JSON string loads synchronously, before it, and
    // onMapCreated's reset then discarded the loaded style: no map in dark
    // mode (found on the device, Spec 19).
    test(
      'German hands MapLibre the German style of each brightness (#128)',
      () {
        expect(liveMapStyle(false, 'de'), 'assets/map/retrail_light_de.json');
        expect(liveMapStyle(true, 'de'), 'assets/map/retrail_dark_de.json');
      },
    );

    test('dark mode hands MapLibre the bundled Retrail Dark asset path', () {
      expect(liveMapStyle(true, 'en'), 'assets/map/retrail_dark.json');
    });
  });
}
