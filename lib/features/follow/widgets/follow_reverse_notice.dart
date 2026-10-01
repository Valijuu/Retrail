import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../route_follow_providers.dart';

/// Tells the rider once, in a snack bar, when the followed route turned to
/// the opposite direction on its own (Spec 18): why "· opposite direction"
/// shows. Call from the build of a screen that shows the follow chrome.
void listenFollowReverseNotice(WidgetRef ref, BuildContext context) {
  ref.listen(routeFollowProvider.select((s) => s?.reverseNotice), (
    prev,
    next,
  ) {
    if (prev != null || next == null) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(switch (next) {
          FollowReverseNotice.atFinish => l10n.followReverseAtFinish,
          FollowReverseNotice.detected => l10n.followReverseDetected,
        }),
      ),
    );
  });
}
