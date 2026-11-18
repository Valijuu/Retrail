import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/domain/area_filter.dart';
import 'package:retrail/features/history_map/widgets/map_controls.dart';
import 'package:retrail/l10n/app_localizations.dart';

void main() {
  testWidgets('the radius slider reads its value in km (#120)', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: AreaPanel(
            area: AreaFilter(pin: (lat: 48.0, lng: 11.0)),
            onRadius: (_) {},
            onRemove: () {},
          ),
        ),
      ),
    );
    final slider = find.semantics.byPredicate(
      (node) => node.flagsCollection.isSlider,
    );
    final data = slider.evaluate().single.getSemanticsData();
    expect(
      (data.value, data.increasedValue, data.decreasedValue),
      ('Radius: 5 km', 'Radius: 6 km', 'Radius: 4 km'),
    );
    handle.dispose();
  });
}
