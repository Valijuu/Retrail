import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_shapes.dart';
import '../../../core/theme/theme_context.dart';
import '../../../l10n/app_localizations.dart';
import '../photon_client.dart';
import '../place_search_controller.dart';

/// The place search over the map (#106): a text field, the suggestions and
/// the source line. [onPick] gets the chosen place; the field closes itself.
class PlaceSearchPanel extends ConsumerStatefulWidget {
  const PlaceSearchPanel({super.key, required this.onPick});

  final ValueChanged<PlaceSuggestion> onPick;

  @override
  ConsumerState<PlaceSearchPanel> createState() => _PlaceSearchPanelState();
}

class _PlaceSearchPanelState extends ConsumerState<PlaceSearchPanel> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final search = ref.watch(placeSearchProvider);
    final notifier = ref.read(placeSearchProvider.notifier);

    return Material(
      color: colors.surface.withValues(alpha: _panelAlpha),
      shape: const RoundedRectangleBorder(borderRadius: AppShapes.card),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox(width: 12),
              Icon(Icons.search, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: notifier.setQuery,
                  decoration: InputDecoration(
                    hintText: l10n.placeSearchHint,
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                onPressed: notifier.close,
                tooltip: l10n.placeSearchClose,
                icon: Icon(Icons.close, color: colors.onSurface),
              ),
            ],
          ),
          if (search.status == PlaceSearchStatus.loading)
            const LinearProgressIndicator(minHeight: 2),
          for (final place in search.suggestions)
            ListTile(
              dense: true,
              leading: Icon(Icons.place_outlined, color: colors.primary),
              title: Text(place.name),
              subtitle: place.detail.isEmpty ? null : Text(place.detail),
              onTap: () => widget.onPick(place),
            ),
          if (search.status == PlaceSearchStatus.empty ||
              search.status == PlaceSearchStatus.unavailable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                search.status == PlaceSearchStatus.empty
                    ? l10n.placeSearchNone
                    : l10n.placeSearchUnavailable,
                style: text.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l10n.placeSearchSource,
              style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

const double _panelAlpha = 0.95;
