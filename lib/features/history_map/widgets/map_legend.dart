import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_context.dart';
import '../../../domain/activity_type.dart';
import '../../../l10n/app_localizations.dart';
import '../../history/history_providers.dart';
import '../../onboarding/activity_type_ui.dart';
import '../history_map_providers.dart';
import '../legend_toggle.dart';

/// The activity types the history has, each with its icon, colour and visible
/// ride count. A tap shows or hides the type through the shared activity
/// filter, so the list follows (#96).
class MapLegend extends ConsumerWidget {
  const MapLegend({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final present = ref.watch(legendTypesProvider).value ?? const {};
    final selected = ref.watch(
      historyFilterProvider.select((f) => f.activities),
    );
    final types = [
      for (final t in ActivityType.values)
        if (present.contains(t)) t,
    ];
    if (types.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final type in types) ...[
            _LegendChip(
              type: type,
              shown: legendTypeShown(selected, type),
              onTap: () => ref
                  .read(historyFilterProvider.notifier)
                  .setActivities(toggleLegendType(selected, present, type)),
            ),
            const SizedBox(width: _chipGap),
          ],
        ],
      ),
    );
  }
}

/// Opacity of a legend chip while its type is shown or hidden.
const double _shownAlpha = 0.92;
const double _hiddenAlpha = 0.7;

/// Space between two legend chips.
const double _chipGap = 6;

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.type,
    required this.shown,
    required this.onTap,
  });

  final ActivityType type;
  final bool shown;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final line = ActivityMapColors.of(type, Theme.of(context).brightness);
    final l10n = AppLocalizations.of(context);
    final tint = shown ? colors.onSurface : colors.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: shown,
      label: type.label(l10n),
      child: Material(
        color: colors.surface.withValues(
          alpha: shown ? _shownAlpha : _hiddenAlpha,
        ),
        shape: StadiumBorder(
          side: BorderSide(color: shown ? line : colors.onSurfaceVariant),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14,
                  height: 4,
                  decoration: BoxDecoration(
                    color: shown ? line : colors.onSurfaceVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                type.glyph(size: 16, color: tint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
