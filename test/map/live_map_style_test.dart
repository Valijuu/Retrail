import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/map/live_map.dart';
import 'package:retrail/map/openfreemap.dart';

void main() {
  group('liveMapStyle', () {
    test('light mode loads OpenFreeMap Liberty by URL', () {
      expect(liveMapStyle(false), kLibertyStyleUrl);
    });

    // MapLibre loads a Flutter asset path asynchronously, so the style loads
    // after onMapCreated. A JSON string loads synchronously, before it, and
    // onMapCreated's reset then discarded the loaded style: no map in dark
    // mode (found on the device, Spec 19).
    test('dark mode hands MapLibre the bundled Retrail Dark asset path', () {
      expect(liveMapStyle(true), kRetrailDarkStyleAsset);
    });
  });
}
