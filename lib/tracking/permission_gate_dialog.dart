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
        // One row of two equal-width buttons: the default OverflowBar stacked
        // them vertically at different sizes because "Open settings" (DE:
        // "Einstellungen öffnen") doesn't fit next to Cancel at natural size.
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: l10n.actionCancel,
                filled: false,
                onTap: onDismiss,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                label: l10n.permissionOpenSettings,
                filled: true,
                onTap: onOpenSettings,
              ),
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
    // FittedBox: the long localized labels scale down instead of wrapping, so
    // both halves stay the same height.
    final child = FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label, maxLines: 1, softWrap: false));
    return SizedBox(
      height: 44,
      child: filled
          ? FilledButton(onPressed: onTap, child: child)
          : TextButton(onPressed: onTap, child: child),
    );
  }
}
