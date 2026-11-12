import 'package:flutter/material.dart';

import '../../../core/theme/app_shapes.dart';
import '../../../core/theme/theme_context.dart';
import '../../../l10n/app_localizations.dart';
import '../../history_map/widgets/map_controls.dart' show kMapControlHeight;

/// The magnifier among the map controls that opens the place search (#106),
/// in the style of the activity menu button.
class PlaceSearchButton extends StatelessWidget {
  const PlaceSearchButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface.withValues(alpha: _buttonAlpha),
      shape: const RoundedRectangleBorder(borderRadius: AppShapes.pill),
      child: InkWell(
        customBorder: const RoundedRectangleBorder(
          borderRadius: AppShapes.pill,
        ),
        onTap: onPressed,
        child: Tooltip(
          message: AppLocalizations.of(context).placeSearchOpen,
          child: SizedBox(
            height: kMapControlHeight,
            width: kMapControlHeight,
            child: Icon(Icons.search, color: colors.primary, size: 22),
          ),
        ),
      ),
    );
  }
}

const double _buttonAlpha = 0.92;
