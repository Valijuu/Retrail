import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/activity_type.dart';
import 'package:retrail/features/onboarding/activity_type_ui.dart';

void main() {
  test('every activity type maps to its bundled SVG asset', () {
    for (final t in ActivityType.values) {
      expect(t.iconAsset, 'assets/icons/activity/${t.name}.svg');
    }
  });
}
