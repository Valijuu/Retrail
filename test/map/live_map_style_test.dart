import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/map/live_map.dart';

void main() {
  group('liveMapStyleUrl', () {
    test('light mode uses topo-v2', () {
      final url = liveMapStyleUrl(false);
      expect(url, contains('/maps/topo-v2/style.json'));
      expect(url, contains('key=')); // key injected (empty in tests, never committed)
    });
    test('dark mode uses basic-v2-dark (topo has no dark twin)', () {
      expect(liveMapStyleUrl(true), contains('/maps/basic-v2-dark/style.json'));
    });
  });
}
