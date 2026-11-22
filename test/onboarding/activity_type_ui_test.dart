import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/activity_type.dart';
import 'package:retrail/features/onboarding/activity_type_ui.dart';

void main() {
  test('every activity type has its SVG icon bundled', () {
    for (final t in ActivityType.values) {
      expect(File(t.iconAsset).existsSync(), isTrue, reason: t.iconAsset);
    }
  });
}
