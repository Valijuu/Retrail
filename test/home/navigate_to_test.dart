import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/features/home/navigation_chooser.dart';
import 'package:retrail/features/home/navigation_launcher.dart';
import 'package:retrail/l10n/app_localizations.dart';

class _FakeLauncher implements NavigationLauncher {
  _FakeLauncher(this.apps);
  final List<NavigationApp> apps;
  final launches = <(NavigationApp, double, double, String)>[];

  @override
  Future<List<NavigationApp>> availableApps() async => apps;

  @override
  Future<void> launch(
          NavigationApp app, double lat, double lng, String label) async =>
      launches.add((app, lat, lng, label));
}

void main() {
  Future<void> pumpAndTap(WidgetTester tester, _FakeLauncher launcher) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                navigateTo(context, launcher, 52.5, 13.4, 'Morning roll'),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  testWidgets('a single available app launches directly, no chooser',
      (tester) async {
    final launcher = _FakeLauncher([NavigationApp.system]);
    await pumpAndTap(tester, launcher);

    expect(find.byType(BottomSheet), findsNothing);
    expect(launcher.launches,
        [(NavigationApp.system, 52.5, 13.4, 'Morning roll')]);
  });

  testWidgets('several installed apps open a chooser; the pick is launched',
      (tester) async {
    final launcher = _FakeLauncher([
      NavigationApp.appleMaps,
      NavigationApp.googleMaps,
      NavigationApp.waze,
    ]);
    await pumpAndTap(tester, launcher);

    expect(find.text('Navigate with'), findsOneWidget);
    expect(find.text('Apple Maps'), findsOneWidget);
    expect(find.text('Google Maps'), findsOneWidget);
    expect(find.text('Waze'), findsOneWidget);
    expect(launcher.launches, isEmpty);

    await tester.tap(find.text('Google Maps'));
    await tester.pumpAndSettle();
    expect(launcher.launches,
        [(NavigationApp.googleMaps, 52.5, 13.4, 'Morning roll')]);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('dismissing the chooser launches nothing', (tester) async {
    final launcher =
        _FakeLauncher([NavigationApp.appleMaps, NavigationApp.waze]);
    await pumpAndTap(tester, launcher);

    await tester.tapAt(const Offset(10, 10)); // scrim
    await tester.pumpAndSettle();
    expect(launcher.launches, isEmpty);
  });
}
