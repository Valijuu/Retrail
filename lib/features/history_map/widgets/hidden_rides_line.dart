import 'package:flutter/material.dart';

import '../../../core/theme/app_shapes.dart';
import '../../../core/theme/theme_context.dart';
import '../../../l10n/app_localizations.dart';

/// "12 of 40 rides" over the map while the header's search or filters hide
/// rides from it (#113); a tap opens the filter sheet.
class HiddenRidesLine extends StatelessWidget {
  const HiddenRidesLine({
    super.key,
    required this.shown,
    required this.total,
    required this.onTap,
  });

  final int shown;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface.withValues(alpha: 0.92),
      shape: const RoundedRectangleBorder(borderRadius: AppShapes.pill),
      child: InkWell(
        customBorder: const RoundedRectangleBorder(
          borderRadius: AppShapes.pill,
        ),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.filter_alt_outlined, size: 18, color: colors.primary),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(
                  context,
                ).historyMapHiddenRides(shown, total),
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: colors.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
