import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/activity_type.dart';
import 'package:retrail/features/history_map/legend_toggle.dart';

const _lb = ActivityType.longboard;
const _ski = ActivityType.ski;
const _sb = ActivityType.snowboard;

void main() {
  test('hiding a type while all show keeps the other present types', () {
    expect(toggleLegendType({}, {_lb, _ski}, _ski), {_lb});
  });

  test('showing a hidden type adds it back', () {
    expect(toggleLegendType({_lb}, {_lb, _ski}, _ski), isEmpty);
  });

  test('hiding one of three leaves the other two', () {
    expect(toggleLegendType({}, {_lb, _ski, _sb}, _sb), {_lb, _ski});
  });

  test('hiding a shown type of a partial selection removes it', () {
    expect(toggleLegendType({_lb, _ski}, {_lb, _ski, _sb}, _ski), {_lb});
  });

  test('showing every present type again clears the filter', () {
    expect(toggleLegendType({_lb, _ski}, {_lb, _ski, _sb}, _sb), isEmpty);
  });

  test('the last shown type stays on, it cannot be hidden', () {
    expect(toggleLegendType({_lb}, {_lb, _ski}, _lb), {_lb});
    expect(toggleLegendType({}, {_lb}, _lb), isEmpty);
  });

  test('a type is locked only while it is the single shown one', () {
    expect(legendTypeLocked({_lb}, {_lb, _ski}, _lb), isTrue);
    expect(legendTypeLocked({_lb}, {_lb, _ski}, _ski), isFalse);
    expect(legendTypeLocked({}, {_lb}, _lb), isTrue);
    expect(legendTypeLocked({}, {_lb, _ski}, _lb), isFalse);
    expect(legendTypeLocked({_lb, _ski}, {_lb, _ski, _sb}, _lb), isFalse);
  });

  test('a type is shown when the filter is empty or contains it', () {
    expect(legendTypeShown({}, _ski), isTrue);
    expect(legendTypeShown({_lb}, _ski), isFalse);
    expect(legendTypeShown({_lb}, _lb), isTrue);
  });
}
