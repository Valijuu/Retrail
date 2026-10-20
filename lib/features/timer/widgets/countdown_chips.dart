import 'package:flutter/material.dart';

import '../../../core/theme/app_shapes.dart';
import '../../../domain/activity_type.dart';
import '../../../l10n/app_localizations.dart';
import '../../onboarding/activity_type_ui.dart';
import 'countdown_palette.dart';

class CountdownActivityChip extends StatelessWidget {
  const CountdownActivityChip({super.key, required this.activity});
  final ActivityType activity;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: countdownSurface.surfaceContainer,
        borderRadius: AppShapes.pill,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          activity.glyph(size: 18, color: countdownAccent.primaryContainer),
          const SizedBox(width: 8),
          Text(
            activity.label(l10n),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: countdownAccent.primaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class CountdownAddTimeChip extends StatelessWidget {
  const CountdownAddTimeChip({
    super.key,
    required this.label,
    required this.onTap,
  });
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: countdownSurface.surfaceContainer,
      borderRadius: AppShapes.pill,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppShapes.pill,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: countdownAccent.primaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
