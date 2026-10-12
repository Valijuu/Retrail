import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_context.dart';
import '../../../l10n/app_localizations.dart';
import '../history_providers.dart';

/// History's empty list. Under a filter or search that can hide rides it says
/// "no matches" and offers a reset — "No rides yet" there read as if the
/// whole history were gone (issue #74).
class HistoryEmptyState extends ConsumerWidget {
  const HistoryEmptyState({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final narrowed = ref.watch(historyNarrowsRidesProvider);
    final message = Text(
      narrowed ? l10n.historyNoMatches : l10n.historyEmpty,
      textAlign: TextAlign.center,
      style: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(color: colors.onSurfaceVariant),
    );
    if (!narrowed) return Center(child: message);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          message,
          const SizedBox(height: 8),
          TextButton(
            onPressed: ref.read(historyFilterProvider.notifier).reset,
            child: Text(l10n.historyResetFilters,
                style: TextStyle(color: colors.primary)),
          ),
        ],
      ),
    );
  }
}
