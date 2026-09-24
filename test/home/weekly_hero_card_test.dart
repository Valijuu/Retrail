import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/domain/stats_aggregation.dart';
import 'package:retrail/features/home/home_providers.dart';
import 'package:retrail/features/home/weekly_hero_card.dart';
import 'package:retrail/l10n/app_localizations.dart';

const _day = WeeklyStats(
    totalKm: 1, rideCount: 1, avgSpeedKmh: 11, totalDurationSeconds: 60);
const _week = WeeklyStats(
    totalKm: 5, rideCount: 3, avgSpeedKmh: 12, totalDurationSeconds: 600);
const _year = WeeklyStats(
    totalKm: 50, rideCount: 42, avgSpeedKmh: 13, totalDurationSeconds: 6000);

void main() {
  Future<void> pumpCard(WidgetTester tester, StatsPeriod selected,
      {Locale? locale}) async {
    await tester.pumpWidget(MaterialApp(
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
        body: StatefulBuilder(
          builder: (_, _) => WeeklyHeroCard(
            daily: _day,
            weekly: _week,
            yearly: _year,
            selected: selected,
            onSelect: (_) {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('the bottom row shows the selected period — week', (tester) async {
    await pumpCard(tester, StatsPeriod.week);
    expect(find.text('3'), findsOneWidget); // week ride count
    expect(find.text('42'), findsNothing);
  });

  testWidgets('the bottom row shows the selected period — year', (tester) async {
    await pumpCard(tester, StatsPeriod.year);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('3'), findsNothing);
  });

  testWidgets('the selected column is marked selected for accessibility',
      (tester) async {
    await pumpCard(tester, StatsPeriod.day);
    expect(tester.getSemantics(find.text('Today')),
        isSemantics(isSelected: true, isButton: true, hasTapAction: true));
    expect(tester.getSemantics(find.text('This week')),
        isSemantics(isSelected: false));
  });

  testWidgets('tapping a column selects its period', (tester) async {
    StatsPeriod? tapped;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: WeeklyHeroCard(
          daily: _day,
          weekly: _week,
          yearly: _year,
          selected: StatsPeriod.week,
          onSelect: (p) => tapped = p,
        ),
      ),
    ));
    await tester.tap(find.text('This year'));
    expect(tapped, StatsPeriod.year);
  });

  testWidgets('German uses the decimal comma for km and Ø speed',
      (tester) async {
    await pumpCard(tester, StatsPeriod.week, locale: const Locale('de'));
    expect(find.text('5,0 km'), findsOneWidget);
    expect(find.text('Ø 12,0'), findsOneWidget);
  });
}
