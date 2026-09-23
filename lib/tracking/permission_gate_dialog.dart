import 'package:flutter/material.dart';

import '../core/widgets/stacked_dialog_actions.dart';
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
        StackedDialogActions(
          primaryLabel: l10n.permissionOpenSettings,
          onPrimary: onOpenSettings,
          secondaryLabel: l10n.actionCancel,
          onSecondary: onDismiss,
        ),
      ],
    );
  }
}
