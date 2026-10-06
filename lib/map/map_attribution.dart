import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_shapes.dart';
import '../core/theme/theme_context.dart';
import '../l10n/app_localizations.dart';
import 'map_config.dart';

/// Opens a map credit's page in the browser — the [MapAttribution] `onOpen`
/// of every interactive map.
void openMapCopyright(Uri page) =>
    launchUrl(page, mode: LaunchMode.externalApplication);

/// Whether this app start has shown an expanded collapsible credit yet
/// (Spec 19 §C). A plain flag: nothing watches it.
class MapCreditSession {
  bool expandedShown = false;
}

final mapCreditSessionProvider = Provider<MapCreditSession>(
  (ref) => MapCreditSession(),
);

/// How long a collapsible credit stays expanded without a touch.
const Duration kMapCreditCollapseDelay = Duration(seconds: 5);

/// Gap between a map's bottom edge and its [MapAttribution].
const double kMapAttributionInset = 4.0;

/// The "© OpenMapTiles © OpenStreetMap" credit the OpenMapTiles (CC BY) and
/// OSM licences require on every map; the `maplibre` package hides the
/// native attribution control, so the screens draw this one.
///
/// With [onOpen] each credit is tappable. [collapsible] (live maps): the
/// first one after an app start shows expanded and collapses to an ⓘ after
/// [kMapCreditCollapseDelay] or a touch outside it; later ones start as ⓘ
/// (the OSMF guidelines allow both). Tapping ⓘ expands it again.
class MapAttribution extends ConsumerStatefulWidget {
  const MapAttribution({super.key, this.onOpen, this.collapsible = false});

  final ValueChanged<Uri>? onOpen;
  final bool collapsible;

  @override
  ConsumerState<MapAttribution> createState() => _MapAttributionState();
}

class _MapAttributionState extends ConsumerState<MapAttribution> {
  bool _expanded = true;
  Timer? _collapseTimer;

  @override
  void initState() {
    super.initState();
    if (!widget.collapsible) return;
    final session = ref.read(mapCreditSessionProvider);
    _expanded = !session.expandedShown;
    session.expandedShown = true;
    if (_expanded) _scheduleCollapse();
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    if (widget.collapsible) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    }
    super.dispose();
  }

  void _scheduleCollapse() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(kMapCreditCollapseDelay, _collapse);
  }

  void _collapse() {
    _collapseTimer?.cancel();
    if (mounted && _expanded) setState(() => _expanded = false);
  }

  void _expand() {
    setState(() => _expanded = true);
    _scheduleCollapse();
  }

  /// Any touch outside the credit collapses it; touches on it (its links)
  /// must land first.
  void _onPointer(PointerEvent event) {
    if (event is! PointerDownEvent || !_expanded) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return;
    final local = box.globalToLocal(event.position);
    if (!(Offset.zero & box.size).contains(local)) _collapse();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    if (!_expanded) {
      return Material(
        color: colors.surface.withValues(alpha: _backgroundAlpha),
        shape: const CircleBorder(),
        child: IconButton(
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          tooltip: l10n.mapCreditsCd,
          onPressed: _expand,
          icon: Icon(Icons.info_outline, color: colors.onSurfaceVariant),
        ),
      );
    }
    final style = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant);

    Widget credit(String label, Uri page) {
      final text = Text(label, style: style);
      final open = widget.onOpen;
      return open == null
          ? text
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => open(page),
              child: text,
            );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: _backgroundAlpha),
        borderRadius: AppShapes.input,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Wrap(
          spacing: 4,
          alignment: WrapAlignment.center,
          children: [
            credit(
              l10n.mapAttributionOpenMapTiles,
              MapConfig.openMapTilesCopyright,
            ),
            credit(l10n.mapAttributionOsm, MapConfig.osmCopyright),
          ],
        ),
      ),
    );
  }
}

/// Enough to read the credit over busy tiles, light enough to see the map.
const double _backgroundAlpha = 0.75;
