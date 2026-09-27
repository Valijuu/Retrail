import 'package:flutter/material.dart';

import '../../core/theme/theme_context.dart';
import '../../l10n/app_localizations.dart';
import 'navigation_launcher.dart';

/// Navigates to the labelled coordinate: launches straight away when only one
/// app is available (Android's own chooser, or Apple Maps alone), otherwise
/// lets the user pick from the installed apps first.
Future<void> navigateTo(BuildContext context, NavigationLauncher launcher,
    double lat, double lng, String label) async {
  final apps = await launcher.availableApps();
  if (!context.mounted) return;
  final app = apps.length == 1
      ? apps.single
      : await showModalBottomSheet<NavigationApp>(
          context: context,
          useSafeArea: true,
          showDragHandle: true,
          backgroundColor: context.colors.surface,
          builder: (_) => _NavigationAppSheet(apps),
        );
  if (app != null) await launcher.launch(app, lat, lng, label);
}

class _NavigationAppSheet extends StatelessWidget {
  const _NavigationAppSheet(this.apps);

  final List<NavigationApp> apps;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(l10n.navigateWithTitle,
              style: Theme.of(context).textTheme.titleMedium),
        ),
        for (final app in apps)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: Icon(Icons.map_outlined, color: context.colors.primary),
            title: Text(_name(l10n, app)),
            onTap: () => Navigator.of(context).pop(app),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  static String _name(AppLocalizations l10n, NavigationApp app) =>
      switch (app) {
        NavigationApp.appleMaps => l10n.navigationAppAppleMaps,
        NavigationApp.googleMaps => l10n.navigationAppGoogleMaps,
        NavigationApp.waze => l10n.navigationAppWaze,
        // A single app launches directly, and Android only ever has [system].
        NavigationApp.system =>
          throw StateError('the system chooser is never listed'),
      };
}
