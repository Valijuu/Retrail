import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:retrail/domain/formatters.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  final nowMs = DateTime(2026, 6, 17, 10, 0).millisecondsSinceEpoch;

  String label(String key) => formatDateLabel(
        key,
        todayLabel: 'Today',
        yesterdayLabel: 'Yesterday',
        locale: 'en',
        nowMs: nowMs,
      );

  test('today and yesterday use the supplied labels', () {
    expect(label('2026-06-17'), 'Today');
    expect(label('2026-06-16'), 'Yesterday');
  });

  test('other days use a localized MMMMd', () {
    expect(label('2026-06-10'), 'June 10');
  });

  test('an unparseable key is returned unchanged', () {
    expect(
      formatDateLabel('not-a-date',
          todayLabel: 'T', yesterdayLabel: 'Y', nowMs: nowMs),
      'not-a-date',
    );
  });
}
