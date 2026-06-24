import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:retrail/domain/ride_title.dart';

import 'domain_test_helpers.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  test('non-blank description is used verbatim', () {
    expect(rideDisplayTitle(buildRide(description: 'Sunset cruise')),
        'Sunset cruise');
  });

  test('blank or null description falls back to the FULL date', () {
    final ts = DateTime(2026, 6, 15).millisecondsSinceEpoch;
    final expected = DateFormat.yMMMMEEEEd('en').format(DateTime(2026, 6, 15));

    expect(rideDisplayTitle(buildRide(date: ts), locale: 'en'), expected);
    expect(rideDisplayTitle(buildRide(description: '   ', date: ts), locale: 'en'),
        expected);
  });

  test('uses startTime when date is null, and is never empty', () {
    final ts = DateTime(2026, 1, 2).millisecondsSinceEpoch;
    final title = rideDisplayTitle(buildRide(startTime: ts), locale: 'en');
    expect(title, DateFormat.yMMMMEEEEd('en').format(DateTime(2026, 1, 2)));
  });
}
