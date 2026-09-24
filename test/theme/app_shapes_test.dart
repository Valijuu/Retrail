import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_shapes.dart';

void main() {
  group('AppShapes radii', () {
    test('intent-named shapes use the original app radii', () {
      expect(AppShapes.heroCard.topLeft.x, 14);
      expect(AppShapes.card.topLeft.x, 12);
      expect(AppShapes.pill.topLeft.x, 50);
      expect(AppShapes.input.topLeft.x, 10);
      expect(AppShapes.dialog.topLeft.x, 20);
    });
  });
}
