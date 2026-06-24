import 'package:flutter/material.dart';

/// Corner radii used across Retrail, carried verbatim from the original app.
/// The original applied these per-widget (different cards use different radii),
/// so these are exposed as constants for use in each screen rather than as
/// global component themes.
abstract final class AppShapes {
  /// Hero card, route map containers.
  static const BorderRadius heroCard = BorderRadius.all(Radius.circular(14));

  /// Recent-ride cards, stat cells.
  static const BorderRadius card = BorderRadius.all(Radius.circular(12));

  /// FAB / pill buttons.
  static const BorderRadius pill = BorderRadius.all(Radius.circular(50));

  /// GPS status line, dialog input fields.
  static const BorderRadius input = BorderRadius.all(Radius.circular(10));

  /// Small icon containers.
  static const BorderRadius iconContainer = BorderRadius.all(Radius.circular(8));

  static const RoundedRectangleBorder heroCardBorder =
      RoundedRectangleBorder(borderRadius: heroCard);
  static const RoundedRectangleBorder cardBorder =
      RoundedRectangleBorder(borderRadius: card);
  static const RoundedRectangleBorder pillBorder =
      RoundedRectangleBorder(borderRadius: pill);
  static const RoundedRectangleBorder inputBorder =
      RoundedRectangleBorder(borderRadius: input);
  static const RoundedRectangleBorder iconContainerBorder =
      RoundedRectangleBorder(borderRadius: iconContainer);
}
