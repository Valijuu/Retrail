import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/activity_type.dart';
import 'package:retrail/features/history_map/map_activities.dart';

const _lb = ActivityType.longboard;
const _ski = ActivityType.ski;
const _sb = ActivityType.snowboard;

void main() {
  test('unticking a type while all show keeps the other present types', () {
    expect(toggleMapType(null, {_lb, _ski}, _ski), {_lb});
    expect(toggleMapType(null, {_lb, _ski, _sb}, _sb), {_lb, _ski});
  });

  test('ticking every present type again is "every type"', () {
    expect(toggleMapType({_lb}, {_lb, _ski}, _ski), isNull);
    expect(toggleMapType({_lb, _ski}, {_lb, _ski, _sb}, _sb), isNull);
  });

  test('the last shown type can be unticked, leaving none', () {
    expect(toggleMapType({_lb}, {_lb, _ski}, _lb), isEmpty);
  });

  test('a partial selection toggles its own members', () {
    expect(toggleMapType({_lb, _ski}, {_lb, _ski, _sb}, _ski), {_lb});
    expect(toggleMapType({_lb}, {_lb, _ski, _sb}, _ski), {_lb, _ski});
  });

  test('"all" is none when every type is on, every type otherwise', () {
    expect(toggleAllMapTypes(null, {_lb, _ski}), isEmpty);
    expect(toggleAllMapTypes({_lb, _ski}, {_lb, _ski}), isEmpty);
    expect(toggleAllMapTypes({_lb}, {_lb, _ski}), isNull);
    expect(toggleAllMapTypes({}, {_lb, _ski}), isNull);
  });

  test('a type is shown when the selection is every type or has it', () {
    expect(mapTypeShown(null, _ski), isTrue);
    expect(mapTypeShown({_lb}, _ski), isFalse);
    expect(mapTypeShown({_lb}, _lb), isTrue);
    expect(mapTypeShown({}, _lb), isFalse);
  });
}
