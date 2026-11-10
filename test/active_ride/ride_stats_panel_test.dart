import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_colors.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/domain/elevation.dart';
import 'package:retrail/features/active_ride/widgets/ride_stats_panel.dart';
import 'package:retrail/l10n/app_localizations.dart';
import 'package:retrail/tracking/ride_tracking_state.dart';

Widget _host(
  RideTrackingState state,
  Brightness brightness, {
  Locale? locale,
}) => MaterialApp(
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
    final colors = brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;

    testWidgets('$brightness: outlined Pause / Stop ride labels are primary', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const RideTrackingState(isTracking: true), brightness),
      );
      expect(_labelColor(tester, 'Pause'), colors.primary);
      expect(_labelColor(tester, 'Stop ride'), colors.primary);
    });

    testWidgets('$brightness: filled Resume label (paused) is onPrimary', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const RideTrackingState(isTracking: true, isPaused: true),
          brightness,
        ),
      );
      expect(_labelColor(tester, 'Resume'), colors.onPrimary);
    });
  }

  testWidgets('German uses the decimal comma for speed and distance', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const RideTrackingState(
          isTracking: true,
          speedKmh: 12.3,
          distanceMetres: 1234,
        ),
        Brightness.light,
        locale: const Locale('de'),
      ),
    );
    expect(find.text('12,3 km/h'), findsWidgets);
    expect(find.text('1,23 km'), findsOneWidget);
  });

  group('ascent (#97)', () {
    testWidgets('shows the running ascent once the ride has altitude data', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const RideTrackingState(
            isTracking: true,
            elevation: ElevationGain(ascent: 42.4, descent: 10),
          ),
          Brightness.light,
        ),
      );
      expect(find.text('Ascent'), findsOneWidget);
      expect(find.text('42 m'), findsOneWidget);
      expect(find.text('Descent'), findsOneWidget);
      expect(find.text('10 m'), findsOneWidget);
    });

    testWidgets('both rows have three equally wide cells with data', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const RideTrackingState(
            isTracking: true,
            elevation: ElevationGain(ascent: 5, descent: 3),
          ),
          Brightness.light,
        ),
      );
      final widths = [
        for (final label in ['Speed', 'Top speed', 'Ascent', 'Descent'])
          tester
              .getSize(
                find
                    .ancestor(
                      of: find.text(label),
                      matching: find.byType(Container),
                    )
                    .first,
              )
              .width,
      ];
      expect(widths.toSet(), hasLength(1));
    });

    testWidgets('without altitude data the cells read -- m, never 0 m', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const RideTrackingState(isTracking: true), Brightness.light),
      );
      expect(find.text('Ascent'), findsOneWidget);
      expect(find.text('Descent'), findsOneWidget);
      expect(find.text('-- m'), findsNWidgets(2));
      expect(find.text('0 m'), findsNothing);
    });

    testWidgets('keeps the panel height with and without the value', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const RideTrackingState(isTracking: true), Brightness.light),
      );
      final without = tester.getSize(find.byType(RideStatsPanel));
      await tester.pumpWidget(
        _host(
          const RideTrackingState(
            isTracking: true,
            elevation: ElevationGain(ascent: 5, descent: 0),
          ),
          Brightness.light,
        ),
      );
      expect(tester.getSize(find.byType(RideStatsPanel)), without);
    });

    testWidgets('fits a narrow phone in German without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _host(
          const RideTrackingState(
            isTracking: true,
            elapsedSeconds: 3725,
            maxSpeedKmh: 33.3,
            elevation: ElevationGain(ascent: 1234, descent: 0),
          ),
          Brightness.light,
          locale: const Locale('de'),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Aufstieg'), findsOneWidget);
    });
  });
}
