import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shapes.dart';
import '../../../core/theme/theme_context.dart';
import '../../../domain/activity_type.dart';
import '../../../l10n/app_localizations.dart';
import '../../history/history_providers.dart';
import '../../onboarding/activity_type_ui.dart';
import '../history_map_providers.dart';
import '../legend_toggle.dart';
import 'map_controls.dart' show kMapControlHeight;

/// Width of the colour bar in front of an activity in the menu.
const double _colourBarWidth = 14;
const double _colourBarHeight = 4;
const double _glyphSize = 18;

/// One drop-down for the activity types of the history: each with its map
/// colour and icon and a checkbox. Ticking works on the shared activity
/// filter, so the list follows (#96). The menu stays open while ticking.
class ActivityMenu extends ConsumerWidget {
  const ActivityMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final brightness = Theme.of(context).brightness;
    final present = ref.watch(legendTypesProvider).value ?? const {};
    final selected = ref.watch(
      historyFilterProvider.select((f) => f.activities),
    );
    final types = [
      for (final t in ActivityType.values)
        if (present.contains(t)) t,
    ];
    if (types.isEmpty) return const SizedBox.shrink();
    final shownCount = types.where((t) => legendTypeShown(selected, t)).length;

    return MenuAnchor(
      menuChildren: [
        CheckboxMenuButton(
          closeOnActivate: false,
          tristate: true,
          value: shownCount == types.length ? true : null,
          onChanged: types.length < 2
              ? null
              : (_) => ref
                    .read(historyFilterProvider.notifier)
                    .setActivities(toggleAllLegendTypes(selected, present)),
          child: Text(l10n.historyMapAllActivities),
        ),
        const Divider(height: 1),
        for (final type in types)
          CheckboxMenuButton(
            closeOnActivate: false,
            value: legendTypeShown(selected, type),
            // The last shown type stays on: the empty filter means "all".
            onChanged: legendTypeLocked(selected, present, type)
                ? null
                : (_) => ref
                      .read(historyFilterProvider.notifier)
                      .setActivities(toggleLegendType(selected, present, type)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: _colourBarWidth,
                  height: _colourBarHeight,
                  decoration: BoxDecoration(
                    color: ActivityMapColors.of(type, brightness),
                    borderRadius: BorderRadius.circular(_colourBarHeight / 2),
                  ),
                ),
                const SizedBox(width: 8),
                type.glyph(size: _glyphSize, color: colors.onSurface),
                const SizedBox(width: 8),
                Text(type.label(l10n)),
              ],
            ),
          ),
      ],
      builder: (context, controller, _) => Material(
        color: colors.surface.withValues(alpha: _buttonAlpha),
        shape: const RoundedRectangleBorder(borderRadius: AppShapes.pill),
        child: InkWell(
          customBorder: const RoundedRectangleBorder(
            borderRadius: AppShapes.pill,
          ),
          onTap: () =>
              controller.isOpen ? controller.close() : controller.open(),
          child: Tooltip(
            message: l10n.historyMapActivities,
            child: SizedBox(
              height: kMapControlHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.layers_outlined,
                      color: colors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$shownCount/${types.length}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, color: colors.primary),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opacity of the button over the map.
const double _buttonAlpha = 0.92;
