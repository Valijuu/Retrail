import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/features/shell/startup_failure_screen.dart';

void main() {
  // #139: a failing database open used to leave the launch screen up for good.
  testWidgets('shows the message and a retry button', (tester) async {
    await tester.pumpWidget(
      StartupFailureApp(retry: () async => false, onRecovered: () {}),
    );
    expect(find.text('Retrail can’t open your rides right now'), findsOne);
    expect(find.text('Try again'), findsOne);
  });

  testWidgets('a retry that works hands over to the app', (tester) async {
    var recovered = 0;
    await tester.pumpWidget(
      StartupFailureApp(
        retry: () async => true,
        onRecovered: () => recovered++,
      ),
    );
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(recovered, 1);
  });

  testWidgets('a retry that fails again stays and can be repeated', (
    tester,
  ) async {
    var tries = 0;
    var recovered = 0;
    await tester.pumpWidget(
      StartupFailureApp(
        retry: () async => ++tries > 1,
        onRecovered: () => recovered++,
      ),
    );
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(recovered, 0);
    expect(find.text('Try again'), findsOne); // enabled again, not stuck busy
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(recovered, 1);
  });
}
