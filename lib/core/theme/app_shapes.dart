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

  /// FAB / pill buttons, chips, the nav-bar selection indicator.
  static const BorderRadius pill = BorderRadius.all(Radius.circular(50));

  /// GPS status line, dialog input fields, small icon containers.
  static const BorderRadius input = BorderRadius.all(Radius.circular(10));

  /// Dialogs (stop / discard / post-ride summary, ride detail, edit, delete).
  static const BorderRadius dialog = BorderRadius.all(Radius.circular(20));
}
