import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_sensei/features/focus/services/focus_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  late List<MethodCall> calls;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      // Permissions denied and exact alarms unavailable: scheduling still uses
      // the safe fallback and the timer remains independent of the permission.
      if (call.method == 'initialize') return true;
      return false;
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  for (final platform in [TargetPlatform.iOS]) {
    test('$platform prompts once, schedules UTC deadline and cancels stable ID',
        () async {
      debugDefaultTargetPlatformOverride = platform;
      final service = LocalFocusNotifications();
      await service.requestPermission();
      await service.requestPermission();
      final end = DateTime.now().toUtc().add(const Duration(minutes: 25));
      await service.schedule(
          end, 'Focus complete', 'Nice work. Your session is done.');
      await service.cancel();
      final permissionMethod = platform == TargetPlatform.android
          ? 'requestNotificationsPermission'
          : 'requestPermissions';
      expect(calls.where((c) => c.method == permissionMethod).length, 1);
      final schedule = calls
          .singleWhere((c) => c.method == 'zonedSchedule')
          .arguments as Map;
      expect(schedule['id'], LocalFocusNotifications.notificationId);
      expect(schedule['timeZoneName'], 'UTC');
      expect(schedule['title'], 'Focus complete');
      expect(calls.singleWhere((c) => c.method == 'cancel').arguments,
          LocalFocusNotifications.notificationId);
      if (platform == TargetPlatform.android) {
        expect((schedule['platformSpecifics'] as Map)['scheduleMode'],
            'inexactAllowWhileIdle');
      }
      await LocalFocusNotifications().requestPermission();
      expect(calls.where((c) => c.method == permissionMethod).length, 1);
    });
  }
}
