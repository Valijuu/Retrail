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
  home: Scaffold(
    body: Stack(
      children: [
        const Positioned(
          top: 0,
          left: 0,
          child: SizedBox(key: Key('elsewhere'), width: 50, height: 50),
        ),
        Center(child: child),
      ],
    ),
  ),
);

final _info = find.byIcon(Icons.info_outline);

void main() {
  testWidgets('credits OpenMapTiles and OpenStreetMap (EN)', (tester) async {
    await tester.pumpWidget(_host(const MapAttribution()));
    expect(find.text('© OpenMapTiles'), findsOneWidget);
    expect(find.text('© OpenStreetMap'), findsOneWidget);
  });

  testWidgets('German: the same short credit', (tester) async {
    await tester.pumpWidget(
      _host(const MapAttribution(), locale: const Locale('de')),
    );
    expect(find.text('© OpenMapTiles'), findsOneWidget);
    expect(find.text('© OpenStreetMap'), findsOneWidget);
  });

  testWidgets('with onOpen: each credit opens its page', (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(_host(MapAttribution(onOpen: opened.add)));
    await tester.tap(find.text('© OpenMapTiles'));
    await tester.tap(find.text('© OpenStreetMap'));
    expect(opened, [MapConfig.openMapTilesCopyright, MapConfig.osmCopyright]);
  });

  testWidgets('without onOpen: plain text, no tap targets', (tester) async {
    await tester.pumpWidget(_host(const MapAttribution()));
    expect(
      find.descendant(
        of: find.byType(MapAttribution),
        matching: find.byType(GestureDetector),
      ),
      findsNothing,
    );
  });

  testWidgets('stays written out: no collapsing after 5 s', (tester) async {
    await tester.pumpWidget(_host(const MapAttribution()));
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('© OpenStreetMap'), findsOneWidget);
    expect(_info, findsNothing);
  });
}
