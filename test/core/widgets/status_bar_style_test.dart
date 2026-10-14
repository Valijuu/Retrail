import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/core/widgets/status_bar_style.dart';

final _navigator = GlobalKey<NavigatorState>();

Future<void> _pumpApp(WidgetTester tester, ThemeMode mode) async {
  await tester.pumpWidget(MaterialApp(
    navigatorKey: _navigator,
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    themeMode: mode,
    builder: (context, child) => ThemeStatusBar(child: child!),
    home: const Scaffold(body: Text('home')),
  ));
  await tester.pump();
}

Brightness? get _icons => SystemChrome.latestStyle?.statusBarIconBrightness;

void main() {
  testWidgets('light theme: dark status bar icons', (tester) async {
    await _pumpApp(tester, ThemeMode.light);
    expect(_icons, Brightness.dark);
    expect(SystemChrome.latestStyle?.statusBarBrightness, Brightness.light);
  });

  testWidgets('dark theme: light status bar icons', (tester) async {
    await _pumpApp(tester, ThemeMode.dark);
    expect(_icons, Brightness.light);
    expect(SystemChrome.latestStyle?.statusBarBrightness, Brightness.dark);
  });

  testWidgets(
      'light theme: a dark-chrome screen gets light icons, leaving it restores '
      'the dark ones (#66)', (tester) async {
    await _pumpApp(tester, ThemeMode.light);
    _navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const DarkChromeStatusBar(child: Scaffold())));
    await tester.pumpAndSettle();
    expect(_icons, Brightness.light);

    _navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(_icons, Brightness.dark);
  });
}
