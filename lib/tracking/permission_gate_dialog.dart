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
