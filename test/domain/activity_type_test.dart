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
}
