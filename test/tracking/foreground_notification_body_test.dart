import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/tracking/foreground_task_service.dart';

void main() {
  test('notification body: elapsed · distance, in the copy locale', () {
    expect(
        ForegroundTaskService.notificationBody(
            elapsedSeconds: 65, distanceMetres: 1234, locale: 'de'),
        '01:05 · 1,23 km');
    expect(
        ForegroundTaskService.notificationBody(
            elapsedSeconds: 65, distanceMetres: 1234, locale: 'en'),
        '01:05 · 1.23 km');
  });
}
