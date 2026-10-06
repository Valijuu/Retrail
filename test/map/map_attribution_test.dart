import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/l10n/app_localizations.dart';
import 'package:retrail/map/map_attribution.dart';
import 'package:retrail/map/map_config.dart';

Widget _host(Widget child, {Locale? locale}) => MaterialApp(
      locale: locale,
      theme: buildTheme(Brightness.light),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('credits MapTiler and the OpenStreetMap contributors',
      (tester) async {
    await tester.pumpWidget(_host(const MapAttribution()));
    expect(find.text('© MapTiler'), findsOneWidget);
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
  });

  testWidgets('German: the OpenStreetMap credit reads "Mitwirkende"',
      (tester) async {
    await tester.pumpWidget(
        _host(const MapAttribution(), locale: const Locale('de')));
    expect(find.text('© MapTiler'), findsOneWidget);
    expect(find.text('© OpenStreetMap-Mitwirkende'), findsOneWidget);
  });

  testWidgets('with onOpen: each credit opens its copyright page',
      (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(_host(MapAttribution(onOpen: opened.add)));
    await tester.tap(find.text('© MapTiler'));
    await tester.tap(find.text('© OpenStreetMap contributors'));
    expect(opened, [MapConfig.mapTilerCopyright, MapConfig.osmCopyright]);
  });

  testWidgets('without onOpen: plain text, no tap targets', (tester) async {
    await tester.pumpWidget(_host(const MapAttribution()));
    expect(
        find.descendant(
            of: find.byType(MapAttribution),
            matching: find.byType(GestureDetector)),
        findsNothing);
  });
}
