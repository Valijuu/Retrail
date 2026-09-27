import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/l10n/app_localizations.dart';
import 'package:retrail/tracking/location_permission.dart';
import 'package:retrail/tracking/permission_gate_dialog.dart';

void main() {
  Future<void> pumpDialog(WidgetTester tester, LocationStartAction action,
      {VoidCallback? onOpenSettings}) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: PermissionGateDialog(
          action: action,
          onOpenSettings: onOpenSettings ?? () {},
          onDismiss: () {},
        ),
      ),
    ));
  }

  testWidgets(
      'approximate-only location explains why precise is needed and offers '
      'the settings path (issue #28)', (tester) async {
    var opened = false;
    await pumpDialog(tester, LocationStartAction.requestPreciseLocation,
        onOpenSettings: () => opened = true);

    expect(find.text('Precise location needed'), findsOneWidget);
    expect(
        find.text('With approximate location Retrail can\'t record your '
            'route. Allow precise location in the app settings.'),
        findsOneWidget);
    await tester.tap(find.text('Open settings'));
    expect(opened, isTrue);
  });

  testWidgets(
      'long action labels render at full size — stacked full-width buttons, '
      'no shrink-to-fit (issue #31)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpDialog(tester, LocationStartAction.showRationale);

    expect(
        find.descendant(
            of: find.byType(PermissionGateDialog),
            matching: find.byType(FittedBox)),
        findsNothing);
    final open = tester.getSize(find.byType(FilledButton));
    final cancel = tester.getSize(find.byType(TextButton));
    expect(open.width, cancel.width); // same full width, one per row
    expect(tester.getTopLeft(find.byType(FilledButton)).dy,
        lessThan(tester.getTopLeft(find.byType(TextButton)).dy));
  });

  testWidgets(
      'location services off on iOS spells out the Settings path — apps can '
      'only deep-link to their own settings page there', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await pumpDialog(tester, LocationStartAction.openLocationSettings);
    debugDefaultTargetPlatformOverride = null;

    expect(find.text('Turn on location'), findsOneWidget);
    expect(
        find.text('Location Services are off. Turn them on in Settings → '
            'Privacy & Security → Location Services.'),
        findsOneWidget);
  });

  testWidgets('location services off on Android keeps the short copy',
      (tester) async {
    await pumpDialog(tester, LocationStartAction.openLocationSettings);
    expect(find.text('Turn on location to start recording your ride.'),
        findsOneWidget);
  });
}
