import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'location_permission.dart';

/// Shown when the location gate blocks recording — permanently denied
/// ([LocationStartAction.showRationale]) or device location services off
/// ([LocationStartAction.openLocationSettings]). Offers the matching settings
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
    final enableLocation = action == LocationStartAction.openLocationSettings;
    return AlertDialog(
      title: Text(enableLocation
          ? l10n.permissionEnableLocationTitle
          : l10n.permissionLocationTitle),
      content: Text(enableLocation
          ? l10n.permissionEnableLocationBody
          : l10n.permissionLocationBody),
      actions: [
        TextButton(onPressed: onDismiss, child: Text(l10n.actionCancel)),
        FilledButton(
          onPressed: onOpenSettings,
          child: Text(l10n.permissionOpenSettings),
        ),
      ],
    );
  }
}
