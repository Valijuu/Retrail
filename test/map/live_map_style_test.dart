import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/map/live_map.dart';
import 'package:retrail/map/openfreemap.dart';

class _Bundle extends CachingAssetBundle {
  final loaded = <String>[];
  @override
  Future<ByteData> load(String key) => throw UnimplementedError();
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    loaded.add(key);
    return '{"version":8}';
  }
}

void main() {
  group('liveMapStyle', () {
    test('light mode loads OpenFreeMap Liberty by URL', () {
      expect(liveMapStyle(false), kLibertyStyleUrl);
    });
    test('dark mode hands the bundled Retrail Dark JSON to MapLibre', () {
      expect(liveMapStyle(true, darkStyleJson: '{"version":8}'), '{"version":8}');
    });
    test('dark mode before the JSON has loaded: no style yet', () {
      expect(liveMapStyle(true), isNull);
    });
  });

  test('loadRetrailDarkStyle reads the bundled asset', () async {
    final bundle = _Bundle();
    expect(await loadRetrailDarkStyle(bundle), '{"version":8}');
    expect(bundle.loaded, [kRetrailDarkStyleAsset]);
  });
}
