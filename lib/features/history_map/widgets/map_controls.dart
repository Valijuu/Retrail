import 'package:flutter/material.dart';

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
        backgroundColor: colors.surface.withValues(alpha: 0.92),
        visualDensity: VisualDensity.compact,
      ),
      segments: [
        ButtonSegment(
          value: HistoryMapMode.lines,
          label: Text(l10n.historyMapModeLines),
        ),
        ButtonSegment(
          value: HistoryMapMode.heat,
          label: Text(l10n.historyMapModeHeat),
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
/// filter; without a pin it shows the long-press hint instead.
class AreaPanel extends StatelessWidget {
  const AreaPanel({
    super.key,
    required this.area,
    required this.onRadius,
    required this.onRemove,
  });

  final AreaFilter? area;
  final ValueChanged<double> onRadius;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final area = this.area;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: area == null
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  l10n.historyMapPinHint,
                  style: text.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              )
            : Row(
                children: [
                  Text(
                    l10n.historyMapRadius(area.radiusKm.round()),
                    style: text.labelMedium?.copyWith(color: colors.onSurface),
                  ),
                  Expanded(
                    child: Slider(
                      min: AreaFilter.minRadiusKm,
                      max: AreaFilter.maxRadiusKm,
                      divisions:
                          (AreaFilter.maxRadiusKm - AreaFilter.minRadiusKm)
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
