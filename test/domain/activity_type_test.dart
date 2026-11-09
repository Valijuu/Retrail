import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/activity_type.dart';

void main() {
  test('fromId maps known ids', () {
    expect(ActivityType.fromId('LONGBOARD'), ActivityType.longboard);
    expect(ActivityType.fromId('SCOOTER'), ActivityType.scooter);
    expect(ActivityType.fromId('OTHER'), ActivityType.other);
  });

  test('unknown or null id → null', () {
    expect(ActivityType.fromId('NOPE'), isNull);
    expect(ActivityType.fromId(null), isNull);
  });

  test('default type is longboard', () {
    expect(ActivityType.defaultType, ActivityType.longboard);
  });

  test('ids are the uppercase enum names', () {
    for (final type in ActivityType.values) {
      expect(type.id, type.name.toUpperCase());
    }
  });

  group('snow types (#94)', () {
    test('fromId maps SNOWBOARD to snowboard', () {
      expect(ActivityType.fromId('SNOWBOARD'), ActivityType.snowboard);
    });
    test('fromId maps SKI to ski', () {
      expect(ActivityType.fromId('SKI'), ActivityType.ski);
    });
    test('ids of the snow types are SNOWBOARD and SKI', () {
      expect(ActivityType.snowboard.id, 'SNOWBOARD');
      expect(ActivityType.ski.id, 'SKI');
    });
    test('an unknown id such as SURF is still null', () {
      expect(ActivityType.fromId('SURF'), isNull);
    });
    test('pickers list skate types first, snow types after, other last', () {
      expect(ActivityType.values, [
        ActivityType.longboard,
        ActivityType.skateboard,
        ActivityType.mountainboard,
        ActivityType.rollerblades,
        ActivityType.rollerskates,
        ActivityType.scooter,
        ActivityType.snowboard,
        ActivityType.ski,
        ActivityType.other,
      ]);
    });
  });
}
