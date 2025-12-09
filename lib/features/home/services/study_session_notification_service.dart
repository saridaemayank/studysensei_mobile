import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class StudySessionNotificationService {
  StudySessionNotificationService._();

  static final StudySessionNotificationService instance =
      StudySessionNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _supportedPlatform = false;

  static const int _notificationId = 9001;
  static const String _channelId = 'study_session_channel';

  bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      default:
        return false;
    }
  }

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    if (!_isSupportedPlatform) {
      _supportedPlatform = false;
      return;
    }
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestSoundPermission: false,
      requestAlertPermission: true,
      requestBadgePermission: false,
    );
    final initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    try {
      await _plugin.initialize(initSettings);
      _initialized = true;
      _supportedPlatform = true;
    } catch (e) {
      debugPrint('Notification init failed: $e');
      _supportedPlatform = false;
    }
  }

  Future<void> showOngoingNotification({
    required String title,
    required String body,
  }) async {
    await ensureInitialized();
    if (!_supportedPlatform) return;
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      'Study Sessions',
      channelDescription: 'Keeps your StudySensei sessions active',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
    );
    const iosDetails = DarwinNotificationDetails(
      presentSound: false,
      presentBanner: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _plugin.show(
      _notificationId,
      title,
      body,
      details,
    );
  }

  Future<void> cancelNotification() async {
    if (!_initialized || !_supportedPlatform) return;
    await _plugin.cancel(_notificationId);
  }
}
