import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/features/history_map/position_tap.dart';

void main() {
  const here = (lat: 48.0, lng: 11.0);

  test('a tap on the dot hits it', () {
    expect(isTapOnPosition((lat: 48.0, lng: 11.0), here, zoom: 15), isTrue);
  });

  test('a tap a few metres away at a city zoom still hits', () {
    // 0.00003 degrees of latitude is about 3 m; a finger is about 28 px wide.
    expect(isTapOnPosition((lat: 48.00003, lng: 11.0), here, zoom: 15), isTrue);
  });

  test('a tap about a kilometre away misses', () {
    expect(isTapOnPosition((lat: 48.01, lng: 11.0), here, zoom: 15), isFalse);
  });

  test('the reach grows when the map is zoomed out', () {
    const tap = (lat: 48.002, lng: 11.0); // about 220 m
    expect(isTapOnPosition(tap, here, zoom: 17), isFalse);
    expect(isTapOnPosition(tap, here, zoom: 12), isTrue);
  });
}
