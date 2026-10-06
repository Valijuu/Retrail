import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/l10n/app_localizations.dart';
import 'package:retrail/map/map_attribution.dart';
import 'package:retrail/map/map_config.dart';

Widget _host(Widget child, {Locale? locale, ProviderContainer? container}) =>
    UncontrolledProviderScope(
      container: container ?? ProviderContainer(),
      child: MaterialApp(
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

  testWidgets('not collapsible: stays expanded past 5 s', (tester) async {
    await tester.pumpWidget(_host(const MapAttribution()));
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('© OpenStreetMap'), findsOneWidget);
    expect(_info, findsNothing);
  });

  group('collapsible', () {
    testWidgets('the first credit after app start shows expanded, then '
        'collapses to ⓘ after 5 s', (tester) async {
      await tester.pumpWidget(_host(const MapAttribution(collapsible: true)));
      expect(find.text('© OpenStreetMap'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('© OpenStreetMap'), findsNothing);
      expect(_info, findsOneWidget);
    });

    testWidgets('a later credit in the same app start starts as ⓘ', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        _host(const MapAttribution(collapsible: true), container: container),
      );
      await tester.pumpWidget(_host(const SizedBox(), container: container));
      await tester.pumpWidget(
        _host(const MapAttribution(collapsible: true), container: container),
      );
      expect(find.text('© OpenStreetMap'), findsNothing);
      expect(_info, findsOneWidget);
    });

    testWidgets('a touch outside collapses it at once', (tester) async {
      await tester.pumpWidget(_host(const MapAttribution(collapsible: true)));
      await tester.tap(find.byKey(const Key('elsewhere')), warnIfMissed: false);
      await tester.pump();
      expect(_info, findsOneWidget);
    });

    testWidgets('tapping a link while expanded opens it and does not collapse '
        'first', (tester) async {
      final opened = <Uri>[];
      await tester.pumpWidget(
        _host(MapAttribution(collapsible: true, onOpen: opened.add)),
      );
      await tester.tap(find.text('© OpenStreetMap'));
      await tester.pump();
      expect(opened, [MapConfig.osmCopyright]);
      expect(find.text('© OpenStreetMap'), findsOneWidget);
    });

    testWidgets('tapping ⓘ expands it again; it collapses again after 5 s', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const MapAttribution(collapsible: true)));
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(_info);
      await tester.pump();
      expect(find.text('© OpenStreetMap'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(_info, findsOneWidget);
    });

    testWidgets('a rebuild of the same credit keeps its state', (tester) async {
      await tester.pumpWidget(_host(const MapAttribution(collapsible: true)));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(_host(const MapAttribution(collapsible: true)));
      expect(_info, findsOneWidget);
    });

    testWidgets('the ⓘ is announced as "Map credits"', (tester) async {
      final container = ProviderContainer()
        ..read(mapCreditSessionProvider).expandedShown = true;
      addTearDown(container.dispose);
      await tester.pumpWidget(
        _host(const MapAttribution(collapsible: true), container: container),
      );
      expect(find.byTooltip('Map credits'), findsOneWidget);
    });
  });
}
