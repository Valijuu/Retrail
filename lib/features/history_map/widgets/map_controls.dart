import 'package:flutter/material.dart';

import '../../../core/theme/app_shapes.dart';
import '../../../core/theme/theme_context.dart';
import '../../../domain/area_filter.dart';
import '../../../l10n/app_localizations.dart';
import '../history_map_providers.dart';

/// Lines / Heat switch of the map.
class MapModeSwitch extends StatelessWidget {
  const MapModeSwitch({super.key, required this.mode, required this.onChanged});

  final HistoryMapMode mode;
  final ValueChanged<HistoryMapMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    return SegmentedButton<HistoryMapMode>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        backgroundColor: colors.surface.withValues(alpha: _panelAlpha),
        visualDensity: VisualDensity.compact,
      ),
      segments: [
        ButtonSegment(
          value: HistoryMapMode.lines,
          icon: const Icon(Icons.timeline),
          tooltip: l10n.historyMapModeLines,
        ),
        ButtonSegment(
          value: HistoryMapMode.heat,
          icon: const Icon(Icons.local_fire_department),
          tooltip: l10n.historyMapModeHeat,
        ),
      ],
      selected: {mode},
      onSelectionChanged: (s) => onChanged(s.single),
    );
  }
}

/// The round my-location button, in the style of the other floating map
/// buttons: app surface with a primary icon.
class MyLocationButton extends StatelessWidget {
  const MyLocationButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        onPressed: onPressed,
        tooltip: AppLocalizations.of(context).historyMapMyLocation,
        icon: Icon(Icons.my_location, color: colors.primary),
      ),
    );
  }
}

/// Radius slider (`1` to `50` km) and the remove-pin control of the area
/// filter, shown only while a pin is set.
class AreaPanel extends StatelessWidget {
  const AreaPanel({
    super.key,
    required this.area,
    required this.onRadius,
    required this.onRemove,
  });

  final AreaFilter area;
  final ValueChanged<double> onRadius;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: _panelAlpha),
        borderRadius: AppShapes.card,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Text(
              l10n.historyMapRadius(area.radiusKm.round()),
              style: text.labelMedium?.copyWith(color: colors.onSurface),
            ),
            Expanded(
              child: Slider(
                min: AreaFilter.minRadiusKm,
                max: AreaFilter.maxRadiusKm,
                divisions: (AreaFilter.maxRadiusKm - AreaFilter.minRadiusKm)
                    .round(),
                value: area.radiusKm,
                onChanged: onRadius,
              ),
            ),
            IconButton(
              onPressed: onRemove,
              tooltip: l10n.historyMapRemovePin,
              icon: Icon(Icons.location_off, color: colors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opacity of the panels laid over the map, enough to read over busy tiles.
const double _panelAlpha = 0.92;
