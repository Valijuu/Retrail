import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';
import '../../l10n/app_localizations.dart';

/// Single- or batch-delete confirmation. Ports `ConfirmDeleteDialog` — copy is
/// count-aware via ICU plurals.
class ConfirmDeleteDialog extends StatelessWidget {
  const ConfirmDeleteDialog({
    super.key,
    this.count = 1,
    required this.onConfirm,
    required this.onDismiss,
  });

  final int count;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).textTheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration:
            BoxDecoration(color: colors.surface, borderRadius: AppShapes.dialog),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.deleteRidesTitle(count),
                style: text.titleLarge?.copyWith(color: colors.onSurface)),
            const SizedBox(height: 12),
            Text(l10n.deleteRidesBody(count),
                style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onDismiss,
                  child: Text(l10n.actionCancel,
                      style: TextStyle(color: colors.onSurface)),
                ),
                TextButton(
                  onPressed: onConfirm,
                  child: Text(l10n.actionDelete,
                      style: TextStyle(color: colors.deleteActionText)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
