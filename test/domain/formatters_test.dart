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

  group('formatDistanceKm', () {
    test('zero metres renders two decimals — 0.0 -> "0.00 km"', () {
      expect(formatDistanceKm(0.0), '0.00 km');
    });
    test('converts metres to km — 1234.0 -> "1.23 km"', () {
      expect(formatDistanceKm(1234.0), '1.23 km');
    });
    test('keeps a trailing zero — 4200.0 -> "4.20 km"', () {
      expect(formatDistanceKm(4200.0), '4.20 km');
    });
  });

  group('formatDecimal', () {
    test("formatDecimal: no locale, 1 decimal — 18.8 → '18.8'", () {
      expect(formatDecimal(18.8, 1), '18.8');
    });
    test("formatDecimal: German, 1 decimal — 18.8 → '18,8'", () {
      expect(formatDecimal(18.8, 1, locale: 'de'), '18,8');
    });
    test("formatDecimal: English, 2 decimals — 3.5 → '3.50'", () {
      expect(formatDecimal(3.5, 2, locale: 'en'), '3.50');
    });
    test("formatDecimal: German, 2 decimals — 3.5 → '3,50'", () {
      expect(formatDecimal(3.5, 2, locale: 'de'), '3,50');
    });
    test("formatDecimal: 0 decimals rounds — 12.6 → '13', no separator", () {
      expect(formatDecimal(12.6, 0, locale: 'de'), '13');
    });
    test("formatDecimal: no thousands grouping — 1234.5 (de, 1) → '1234,5'", () {
      expect(formatDecimal(1234.5, 1, locale: 'de'), '1234,5');
    });
    test("formatDecimal: region-qualified locale — 'de_DE' → '18,8'", () {
      expect(formatDecimal(18.8, 1, locale: 'de_DE'), '18,8');
    });
  });

  group('formatDistanceKm / formatSpeedKmh with locale', () {
    test("formatDistanceKm: German — 3500 m → '3,50 km'", () {
      expect(formatDistanceKm(3500, locale: 'de'), '3,50 km');
    });
    test("formatSpeedKmh: German — 14.0 → '14,0 km/h'", () {
      expect(formatSpeedKmh(14.0, locale: 'de'), '14,0 km/h');
    });
    test("formatSpeedKmh: German, null → '-- km/h' (placeholder unchanged)", () {
      expect(formatSpeedKmh(null, locale: 'de'), '-- km/h');
    });
  });

  group('formatShortDistanceKm', () {
    test("formatShortDistanceKm: under 10 km one decimal — 3500 m (de) → '3,5 km'", () {
      expect(formatShortDistanceKm(3500, locale: 'de'), '3,5 km');
    });
    test("formatShortDistanceKm: 10 km and up no decimals — 12600 m → '13 km'", () {
      expect(formatShortDistanceKm(12600), '13 km');
    });
    test("formatShortDistanceKm: English — 3500 m → '3.5 km'", () {
      expect(formatShortDistanceKm(3500, locale: 'en'), '3.5 km');
    });
    test("formatShortDistanceKm: 0 m → '0.0 km'", () {
      expect(formatShortDistanceKm(0), '0.0 km');
    });
  });
}
