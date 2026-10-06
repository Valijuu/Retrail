import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_shapes.dart';
import '../core/theme/theme_context.dart';
import '../l10n/app_localizations.dart';
import 'map_config.dart';

/// Opens a map credit's copyright page in the browser — the [MapAttribution]
/// `onOpen` of every interactive map.
void openMapCopyright(Uri page) =>
    launchUrl(page, mode: LaunchMode.externalApplication);

/// The "© MapTiler © OpenStreetMap contributors" credit MapTiler's and OSM's
/// terms require on every map showing their tiles. The `maplibre` package
/// hides the native attribution control on both platforms, so the screens
/// draw this one over their maps and the history previews.
///
/// With [onOpen] each credit is tappable and opens its copyright page; without
/// it (a preview inside a tappable card) it is plain text.
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key, this.onOpen});

  final ValueChanged<Uri>? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final style = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(color: colors.onSurfaceVariant);

    Widget credit(String label, Uri page) {
      final text = Text(label, style: style);
      final open = onOpen;
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
            credit(l10n.mapAttributionMapTiler, MapConfig.mapTilerCopyright),
            credit(l10n.mapAttributionOsm, MapConfig.osmCopyright),
          ],
        ),
      ),
    );
  }
}

/// Gap between a map's bottom edge and its [MapAttribution].
const double kMapAttributionInset = 4.0;

/// Enough to read the credit over busy tiles, light enough to see the map.
const double _backgroundAlpha = 0.75;
