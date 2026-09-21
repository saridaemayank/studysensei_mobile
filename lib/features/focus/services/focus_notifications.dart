import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

abstract interface class FocusNotifications {
  Future<void> requestPermission();
  Future<void> schedule(DateTime end, String title, String body);
  Future<void> cancel();
}

class LocalFocusNotifications implements FocusNotifications {
  static const notificationId = 9002;
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _initialization;
  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  Future<void> _initialize() => _initialization ??= _initializePlugin();
  Future<void> _initializePlugin() async {
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false),
    ));
  }

  @override
  Future<void> requestPermission() async {
    if (!_supported) return;
    await _initialize();
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('focus.notificationPermissionAsked') == true) return;
    await prefs.setBool('focus.notificationPermissionAsked', true);
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } else {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: false, sound: false);
    }
  }

  @override
  Future<void> schedule(DateTime end, String title, String body) async {
    if (!_supported) return;
    await _initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final exact = defaultTargetPlatform == TargetPlatform.android &&
        await android?.canScheduleExactNotifications() == true;
    if (!end.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      notificationId,
      title,
      body,
      tz.TZDateTime.from(end, tz.UTC),
      const NotificationDetails(
        android: AndroidNotificationDetails(
            'focus_completion', 'Focus completion',
            channelDescription: 'Focus and break session completion',
            playSound: false,
            enableVibration: false),
        iOS: DarwinNotificationDetails(
            presentAlert: true, presentSound: false, presentBadge: false),
      ),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Future<void> cancel() async {
    if (!_supported) return;
    await _initialize();
    await _plugin.cancel(notificationId);
  }
}
