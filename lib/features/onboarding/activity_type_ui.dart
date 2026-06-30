import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/activity_type.dart';
import '../../l10n/app_localizations.dart';

/// UI mapping for [ActivityType]: the exact custom SVG glyph and a localized
/// label. The glyphs live in `assets/icons/activity/` (one per enum value,
/// filename = the lowercase enum [name]).
extension ActivityTypeUi on ActivityType {
  /// Bundled SVG asset path for this activity's glyph.
  String get iconAsset => 'assets/icons/activity/$name.svg';

  /// The activity's custom glyph, tinted [color] — or, when null, the ambient
  /// [IconTheme] colour, mirroring how a Material `Icon` adapts to light/dark.
  /// Single-colour SVG, so a srcIn tint recolours the whole glyph.
  Widget glyph({double size = 24, Color? color}) => Builder(
        builder: (context) {
          final tint = color ?? IconTheme.of(context).color;
          return SvgPicture.asset(
            iconAsset,
            width: size,
            height: size,
            colorFilter: tint == null
                ? null
                : ColorFilter.mode(tint, BlendMode.srcIn),
          );
        },
      );

  String label(AppLocalizations l10n) => switch (this) {
        ActivityType.longboard => l10n.activityLongboard,
        ActivityType.skateboard => l10n.activitySkateboard,
        ActivityType.rollerblades => l10n.activityRollerblades,
        ActivityType.rollerskates => l10n.activityRollerskates,
        ActivityType.mountainboard => l10n.activityMountainboard,
        ActivityType.scooter => l10n.activityScooter,
        ActivityType.other => l10n.activityOther,
      };
}
