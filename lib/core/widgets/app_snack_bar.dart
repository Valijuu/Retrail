import 'package:flutter/material.dart';

import '../theme/theme_context.dart';

/// Retrail's snack bar: a short message led by a brand-tinted [icon], with a
/// close icon. Shape and colors come from the theme's `snackBarTheme`. Not
/// persisted — with an [action] Material would otherwise keep it until tapped.
SnackBar appSnackBar({
  required IconData icon,
  required String message,
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 4),
}) => SnackBar(
  content: Builder(
    builder: (context) => Row(
      children: [
        Icon(icon, size: 20, color: context.colors.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(message)),
      ],
    ),
  ),
  action: action,
  // Keep a short message and its action on one line; Material wraps the
  // action below once it takes a quarter of the width.
  actionOverflowThreshold: 1,
  duration: duration,
  persist: false,
  showCloseIcon: true,
);
