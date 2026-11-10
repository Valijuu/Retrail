import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../history_map_providers.dart';

/// The Liste/Karte switch at the top of the History tab (#96). The choice is
/// stored, so it comes back after the app was closed or reopened.
class HistoryViewSwitch extends ConsumerWidget {
  const HistoryViewSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final view = ref.watch(historyViewProvider).value ?? HistoryView.list;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<HistoryView>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: HistoryView.list,
              icon: const Icon(Icons.view_list),
              label: Text(l10n.historyViewList),
            ),
            ButtonSegment(
              value: HistoryView.map,
              icon: const Icon(Icons.map_outlined),
              label: Text(l10n.historyViewMap),
            ),
          ],
          selected: {view},
          onSelectionChanged: (s) =>
              ref.read(historyMapControllerProvider).setView(s.single),
        ),
      ),
    );
  }
}
