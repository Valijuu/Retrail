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
}
