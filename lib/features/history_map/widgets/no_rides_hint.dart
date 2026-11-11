import 'package:flutter/material.dart';

import '../../../core/theme/app_shapes.dart';
import '../../../core/theme/theme_context.dart';

/// The pill over the map while the filters leave no ride to draw (#102), so
/// an empty map does not look like a map that failed to load.
class NoRidesHint extends StatelessWidget {
  const NoRidesHint({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.92),
        borderRadius: AppShapes.pill,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: colors.onSurface),
        ),
      ),
    );
  }
}
