import 'package:flutter/material.dart';

import '../../domain/activity_type.dart';
import '../../l10n/app_localizations.dart';

/// UI mapping for [ActivityType]: a Material-icon stand-in and a localized label.
/// (Exact custom icons can be recreated as SVGs in the polish phase.)
extension ActivityTypeUi on ActivityType {
  IconData get icon => switch (this) {
        ActivityType.longboard => Icons.skateboarding,
        ActivityType.skateboard => Icons.skateboarding,
        ActivityType.rollerblades => Icons.roller_skating,
        ActivityType.rollerskates => Icons.roller_skating,
        ActivityType.mountainboard => Icons.downhill_skiing,
        ActivityType.scooter => Icons.electric_scooter,
        ActivityType.other => Icons.more_horiz,
      };

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
