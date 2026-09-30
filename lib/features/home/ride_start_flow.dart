import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/connectivity/connectivity_providers.dart';
import '../../core/widgets/stacked_dialog_actions.dart';
import '../../l10n/app_localizations.dart';
import '../../tracking/location_permission.dart';
import '../../tracking/permission_gate_dialog.dart';
import '../../tracking/tracking_providers.dart';
import '../shell/routes.dart';
import 'home_providers.dart';

/// The Start-tracking sequence shared by Home and "Follow route → Record":
/// commits the pending activity, asks before an offline start, resolves
/// location (and notification) permission up front — before the countdown,
/// mirroring the original `HomePage` — and opens the countdown when granted.
/// A blocked gate surfaces the rationale / enable-location prompt instead.
/// [beforeCountdown] runs only when the countdown is about to open (the
/// follow launcher sets its reference there, so a blocked or declined start
/// never leaves one behind). Returns whether the countdown was opened.
Future<bool> runRideStartFlow(
  BuildContext context,
  WidgetRef ref, {
  VoidCallback? beforeCountdown,
}) async {
  ref.read(homeControllerProvider).beginTracking();
  final online = ref.read(isOnlineProvider).asData?.value ?? true;
  if (!online && !await _confirmOffline(context)) return false;
  if (!context.mounted) return false;
  final action = await ref.read(rideRecordingControllerProvider).prepare();
  if (!context.mounted) return false;
  if (action == LocationStartAction.proceed) {
    beforeCountdown?.call();
    context.go(AppRoutes.timer);
    return true;
  }
  await showPermissionGateBlocked(context, ref, action);
  return false;
}

Future<void> showPermissionGateBlocked(
  BuildContext context,
  WidgetRef ref,
  LocationStartAction action,
) async {
  final recording = ref.read(rideRecordingControllerProvider);
  await showDialog<void>(
    context: context,
    builder: (c) => PermissionGateDialog(
      action: action,
      onOpenSettings: () {
        Navigator.pop(c);
        action == LocationStartAction.openLocationSettings
            ? recording.openLocationSettings()
            : recording.openAppSettings();
      },
      onDismiss: () => Navigator.pop(c),
    ),
  );
}

Future<bool> _confirmOffline(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(l10n.offlineTrackingTitle),
      content: Text(l10n.offlineTrackingBody),
      actions: [
        StackedDialogActions(
          primaryLabel: l10n.offlineTrackingConfirm,
          onPrimary: () => Navigator.pop(c, true),
          secondaryLabel: l10n.actionSkip,
          onSecondary: () => Navigator.pop(c, false),
        ),
      ],
    ),
  );
  return confirmed == true;
}
