import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Terse, null-safe access to Retrail's [AppColors] token set from any widget:
/// `context.colors.primary`, `context.colors.routeLineBlue`, etc.
extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
