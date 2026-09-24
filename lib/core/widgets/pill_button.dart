import 'package:flutter/material.dart';

import '../theme/app_shapes.dart';

/// Full-height (52dp) pill action used side by side in the ride and history
/// dialogs. The label inherits the button's [fg] — it deliberately sets no
/// text style of its own, since the theme's `labelLarge` carries a color that
/// would override [fg].
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          shape: const RoundedRectangleBorder(borderRadius: AppShapes.pill),
          // Tight side padding so longer (German) labels still fit when two
          // buttons share a dialog row.
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Text(label, maxLines: 1, softWrap: false),
      ),
    );
  }
}
