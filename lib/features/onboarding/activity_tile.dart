import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';
import '../../domain/activity_type.dart';
import '../../l10n/app_localizations.dart';
import 'activity_type_ui.dart';

/// Selectable activity-type tile (icon + label). Selected uses the primary
/// container + border. Reused by onboarding, Settings, and the home picker.
class ActivityTile extends StatelessWidget {
  const ActivityTile({
    super.key,
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final ActivityType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = AppLocalizations.of(context);
    final tint = selected ? colors.primary : colors.onSurfaceVariant;

    return Material(
      color: selected ? colors.primaryContainer : colors.surfaceContainer,
      borderRadius: AppShapes.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppShapes.card,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: AppShapes.card,
            border: Border.all(
              color: selected ? colors.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          // Vertical: glyph centred on top, label centred below (matches the
          // original picker). The label gets the full tile width, so the longest
          // EN/DE label fits on one line; FittedBox shrinks it to fit on very
          // narrow tiles, keeping every tile the same size.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              type.glyph(size: 32, color: tint),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  type.label(l10n),
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: tint, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
