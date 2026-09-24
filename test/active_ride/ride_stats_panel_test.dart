import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_colors.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/features/active_ride/widgets/ride_stats_panel.dart';
import 'package:retrail/l10n/app_localizations.dart';
import 'package:retrail/tracking/ride_tracking_state.dart';

Widget _host(RideTrackingState state, Brightness brightness,
        {Locale? locale}) =>
    MaterialApp(
      locale: locale,
      theme: buildTheme(brightness),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: RideStatsPanel(state: state, onPauseResume: () {}, onStop: () {}),
      ),
    );

Color? _labelColor(WidgetTester tester, String label) =>
    tester.renderObject<RenderParagraph>(find.text(label)).text.style?.color;

void main() {
  for (final brightness in Brightness.values) {
    final colors = brightness == Brightness.dark ? AppColors.dark : AppColors.light;

    testWidgets('$brightness: outlined Pause / Stop ride labels are primary',
        (tester) async {
      await tester.pumpWidget(_host(
          const RideTrackingState(isTracking: true), brightness));
      expect(_labelColor(tester, 'Pause'), colors.primary);
      expect(_labelColor(tester, 'Stop ride'), colors.primary);
    });

    testWidgets('$brightness: filled Resume label (paused) is onPrimary',
        (tester) async {
      await tester.pumpWidget(_host(
          const RideTrackingState(isTracking: true, isPaused: true),
          brightness));
      expect(_labelColor(tester, 'Resume'), colors.onPrimary);
    });
  }

  testWidgets('German uses the decimal comma for speed and distance',
      (tester) async {
    await tester.pumpWidget(_host(
        const RideTrackingState(
            isTracking: true, speedKmh: 12.3, distanceMetres: 1234),
        Brightness.light,
        locale: const Locale('de')));
    expect(find.text('12,3 km/h'), findsWidgets);
    expect(find.text('1,23 km'), findsOneWidget);
  });
}
