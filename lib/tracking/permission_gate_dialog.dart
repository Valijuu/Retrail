import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'location_permission.dart';

/// Shown when the location gate blocks recording — permanently denied
/// ([LocationStartAction.showRationale]), device location services off
/// ([LocationStartAction.openLocationSettings]) or only approximate location
/// granted ([LocationStartAction.requestPreciseLocation]). Offers the matching settings
/// path; [onDismiss] cancels. Shared by the Start-tracking press (home) and the
/// active-ride fallback gate.
class PermissionGateDialog extends StatelessWidget {
  const PermissionGateDialog({
    super.key,
    required this.action,
    required this.onOpenSettings,
    required this.onDismiss,
  });

  final LocationStartAction action;
  final VoidCallback onOpenSettings;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (title, body) = switch (action) {
      LocationStartAction.openLocationSettings => (
          l10n.permissionEnableLocationTitle,
          l10n.permissionEnableLocationBody
        ),
      LocationStartAction.requestPreciseLocation => (
          l10n.permissionPreciseLocationTitle,
          l10n.permissionPreciseLocationBody
        ),
      _ => (l10n.permissionLocationTitle, l10n.permissionLocationBody),
    };
    return AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        // Stacked full-width buttons, primary on top: side by side each got
        // half the width and the long German "Einstellungen öffnen" had to be
        // shrunk to fit, visibly smaller than "Abbrechen" (issue #31).
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ActionButton(
              label: l10n.permissionOpenSettings,
              filled: true,
              onTap: onOpenSettings,
            ),
            const SizedBox(height: 8),
            _ActionButton(
              label: l10n.actionCancel,
              filled: false,
              onTap: onDismiss,
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(
      {required this.label, required this.filled, required this.onTap});

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final child = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    return SizedBox(
      height: 44,
      child: filled
          ? FilledButton(onPressed: onTap, child: child)
          : TextButton(onPressed: onTap, child: child),
    );
  }
}
