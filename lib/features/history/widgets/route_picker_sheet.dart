import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_shapes.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/sheet_input_field.dart';
import '../../../data/db/followed_route.dart';
import '../../../domain/formatters.dart';
import '../../../domain/ride_title.dart';
import '../../../domain/route_selection.dart';
import '../../../l10n/app_localizations.dart';
import '../../../map/preview_projection.dart';
import '../history_providers.dart';
import '../route_group_providers.dart';
import 'ride_preview_thumbnail.dart';

/// Opens the History filter's followed-route picker (Spec 20).
Future<void> showRoutePickerSheet(BuildContext context) =>
    showAppScrollableSheet<void>(
      context: context,
      builder: (_, scrollController) =>
          RoutePickerSheet(scrollController: scrollController),
    );

/// Search and multi-select over the followed routes, newest first. The choice
/// reaches the History filter only on Apply; Reset unchecks everything.
class RoutePickerSheet extends ConsumerStatefulWidget {
  const RoutePickerSheet({super.key, this.scrollController});

  /// The enclosing sheet's controller, so a drag on the list closes it.
  final ScrollController? scrollController;

  @override
  ConsumerState<RoutePickerSheet> createState() => _RoutePickerSheetState();
}

class _RoutePickerSheetState extends ConsumerState<RoutePickerSheet> {
  late Set<int> _selected = {...ref.read(historyFilterProvider).routeIds};
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(int id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
  });

  void _apply() {
    ref.read(historyFilterProvider.notifier).setRouteIds(_selected);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final routes = searchRoutes(
      ref.watch(followedRoutesProvider).value ?? const [],
      _search.text,
      locale: locale,
    );

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: SheetInputField(
              label: l10n.routePickerSearch,
              controller: _search,
              singleLine: true,
            ),
          ),
          Expanded(
            child: routes.isEmpty
                ? Center(
                    child: Text(
                      l10n.routePickerNoMatch,
                      style: text.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView(
                    controller: widget.scrollController,
                    children: [
                      for (final route in routes)
                        _RouteRow(
                          route: route,
                          checked: _selected.contains(route.original.rideId),
                          onTap: () => _toggle(route.original.rideId),
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _selected = {}),
                  child: Text(l10n.actionReset),
                ),
                const Spacer(),
                FilledButton(onPressed: _apply, child: Text(l10n.actionApply)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One followed route: its preview (to tell untitled routes apart), title,
/// ride count and last ride, and a checkbox.
class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.route,
    required this.checked,
    required this.onTap,
  });

  /// The preview's width in the row; its height follows the preview aspect.
  static const double _thumbnailWidth = 72;

  final FollowedRoute route;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final original = route.original;
    return ListTile(
      key: ValueKey('route_picker_row_${original.rideId}'),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: ClipRRect(
        borderRadius: AppShapes.input,
        child: SizedBox(
          width: _thumbnailWidth,
          child: AspectRatio(
            aspectRatio: previewAspectRatio,
            child: RidePreviewThumbnail(
              rideId: original.rideId,
              hasRoute: original.hasRoute,
              cacheWidth:
                  (_thumbnailWidth * MediaQuery.devicePixelRatioOf(context))
                      .round(),
            ),
          ),
        ),
      ),
      title: Text(
        rideDisplayTitle(original, locale: locale),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        l10n.routePickerRides(
          route.rideCount,
          formatRideDay(route.lastRiddenMs, locale: locale),
        ),
      ),
      trailing: Checkbox(value: checked, onChanged: (_) => onTap()),
    );
  }
}
