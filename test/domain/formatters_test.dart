import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:retrail/domain/formatters.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  group('formatDuration / formatElapsed', () {
    test('MM:SS below an hour, H:MM:SS at/above', () {
      expect(formatDuration(0), '00:00');
      expect(formatDuration(59 * 1000), '00:59');
      expect(formatDuration(3599 * 1000), '59:59');
      expect(formatDuration(3600 * 1000), '1:00:00');
      expect(formatDuration(3661 * 1000), '1:01:01');
    });

    test('formatElapsed takes seconds', () {
      expect(formatElapsed(59), '00:59');
      expect(formatElapsed(3661), '1:01:01');
    });
  });

  group('date/time formatters', () {
    test('null timestamps render placeholders', () {
      expect(formatRideDate(null), '—');
      expect(formatRideTime(null), '—');
      expect(formatRideDayKey(null), '0000-00-00');
    });

    test('formats a known local timestamp', () {
      final ms = DateTime(2026, 6, 17, 9, 5).millisecondsSinceEpoch;
      expect(formatRideDate(ms, locale: 'en'), '17.06.2026  09:05');
      expect(formatRideTime(ms, locale: 'en'), '09:05');
      expect(formatRideDayKey(ms), '2026-06-17');
    });
  });

  group('formatSpeedKmh', () {
    test('null renders the placeholder — null -> "-- km/h"', () {
      expect(formatSpeedKmh(null), '-- km/h');
    });
    test('zero renders with one decimal — 0.0 -> "0.0 km/h"', () {
      expect(formatSpeedKmh(0.0), '0.0 km/h');
    });
    test('rounds to one decimal place — 23.456 -> "23.5 km/h"', () {
      expect(formatSpeedKmh(23.456), '23.5 km/h');
    });
  });
}
