import 'package:flutter/material.dart';

import '../../../core/theme/app_shapes.dart';
import '../../../core/theme/theme_context.dart';

/// A tappable line in the ride detail linking to the ride's route group
/// (Spec 20): "Followed from …" to the original, "n× followed" to the
/// comparison.
class RouteLinkRow extends StatelessWidget {
  const RouteLinkRow({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: AppShapes.input,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(Icons.alt_route, size: 18, color: colors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: colors.primary),
          ],
        ),
      ),
    );
  }
}
