import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_shapes.dart';

void main() {
  group('AppShapes radii', () {
    test('intent-named shapes use the original app radii', () {
      expect(AppShapes.heroCard.topLeft.x, 14);
      expect(AppShapes.card.topLeft.x, 12);
      expect(AppShapes.pill.topLeft.x, 50);
      expect(AppShapes.input.topLeft.x, 10);
      expect(AppShapes.iconContainer.topLeft.x, 8);
    });

    test('RoundedRectangleBorder accessors match the radii', () {
      RoundedRectangleBorder border(BorderRadius r) =>
          RoundedRectangleBorder(borderRadius: r);
      expect(AppShapes.heroCardBorder, border(AppShapes.heroCard));
      expect(AppShapes.cardBorder, border(AppShapes.card));
      expect(AppShapes.pillBorder, border(AppShapes.pill));
      expect(AppShapes.inputBorder, border(AppShapes.input));
      expect(AppShapes.iconContainerBorder, border(AppShapes.iconContainer));
    });
  });
}
