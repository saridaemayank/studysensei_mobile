import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockProvider extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('study_sensei/app_lock');
  static const String _enabledKey = 'app_lock_enabled';
  static const String _completionKey = 'app_lock_completion_day';
  static const String _pinKey = 'app_lock_security_pin';
  static const String _minDurationKey = 'app_lock_min_duration_minutes';
  static const int _defaultMinimumMinutes = 25;

  static const List<String> _defaultBlockedPackages = <String>[
    'com.instagram.android',
    'com.google.android.youtube',
    'com.netflix.mediaclient',
    'com.google.android.youtube.tv',
    'com.snapchat.android',
    'com.discord',
    'com.spotify.music',
    'com.facebook.katana',
    'com.facebook.orca',
    'com.twitter.android',
    'com.reddit.frontpage',
    'com.amazon.avod.thirdpartyclient',
    'com.google.android.apps.youtube.music',
  ];

  SharedPreferences? _prefs;

  bool _initialized = false;
  bool _isEnabled = false;
  bool _hasUsagePermission = false;
  bool _hasOverlayPermission = false;
  bool _hasCompletedToday = false;
  String? _storedCompletionDay;
  String? _securityPin;
  int _minimumSessionMinutes = _defaultMinimumMinutes;

  bool get isSupported => !kIsWeb && Platform.isAndroid;
  bool get isInitializing => !_initialized;
  bool get isEnabled => _isEnabled;
  bool get hasUsagePermission => _hasUsagePermission;
  bool get hasOverlayPermission => _hasOverlayPermission;
  bool get hasCompletedToday => _hasCompletedToday;
  bool get permissionsSatisfied => _hasUsagePermission && _hasOverlayPermission;
  bool get shouldShowPermissionWarning => _isEnabled && !permissionsSatisfied;
  List<String> get blockedPackages => _defaultBlockedPackages;
  int get minimumSessionMinutes => _minimumSessionMinutes;

  Future<void> initialize() async {
    if (!isSupported) {
      _initialized = true;
      notifyListeners();
      return;
    }

    final prefs = await _ensurePrefs();
    _isEnabled = prefs.getBool(_enabledKey) ?? false;
    _storedCompletionDay = prefs.getString(_completionKey);
    _hasCompletedToday = _storedCompletionDay == _todayKey();
    _securityPin = prefs.getString(_pinKey);
    _minimumSessionMinutes =
        prefs.getInt(_minDurationKey) ?? _defaultMinimumMinutes;
    if (!_hasCompletedToday && _storedCompletionDay != null) {
      await prefs.remove(_completionKey);
      _storedCompletionDay = null;
    }

    await _refreshPermissions();
    _initialized = true;
    await _syncMonitoring();
    notifyListeners();
  }

  Future<void> toggleAppLock(BuildContext context, bool value) async {
    if (!isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App Lock Mode is only supported on Android devices.')),
      );
      return;
    }

    if (value) {
      if (_securityPin == null) {
        final pinCreated = await _promptCreatePin(context);
        if (!pinCreated) {
          notifyListeners();
          return;
        }
      }
      // ignore: use_build_context_synchronously
      final granted = await ensurePermissions(context);
      if (!context.mounted) return;
      if (!granted) {
        _isEnabled = false;
        final prefs = await _ensurePrefs();
        await prefs.setBool(_enabledKey, false);
        notifyListeners();
        return;
      }
    } else {
      // ignore: use_build_context_synchronously
      final verified = await _verifyPinBeforeDisable(context);
      if (!context.mounted) return;
      if (!verified) {
        notifyListeners();
        return;
      }
    }

    if (_isEnabled == value) {
      return;
    }

    _isEnabled = value;
    final prefs = await _ensurePrefs();
    await prefs.setBool(_enabledKey, value);
    await _syncMonitoring();
    notifyListeners();
  }

  Future<bool> ensurePermissions(BuildContext context) async {
    if (!isSupported) return false;

    await _refreshPermissions();
    if (!context.mounted) {
      return false;
    }
    if (permissionsSatisfied) {
      return true;
    }

    final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Enable App Lock Mode'),
            content: const Text(
              'App Lock Mode needs Usage Access and the ability to draw over other apps. '
              'These permissions let StudySensei detect when entertainment apps open and block them until today\'s study session is done.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Maybe Later'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Grant Permissions'),
              ),
            ],
          ),
        ) ??
        false;

    if (!context.mounted) {
      return false;
    }

    if (!shouldOpenSettings) {
      return false;
    }

    if (!_hasUsagePermission) {
      await _invokeMethod('requestUsageAccess');
    }

    if (!_hasOverlayPermission) {
      await _invokeMethod('requestOverlayPermission');
    }

    await _refreshPermissions();
    return permissionsSatisfied;
  }

  Future<void> refreshPermissions() async {
    await _refreshPermissions();
    notifyListeners();
  }

  Future<void> markStudyCompletedForToday() async {
    if (!isSupported) return;
    final todayKey = _todayKey();
    if (_storedCompletionDay == todayKey && _hasCompletedToday) {
      return;
    }
    _storedCompletionDay = todayKey;
    _hasCompletedToday = true;
    final prefs = await _ensurePrefs();
    await prefs.setString(_completionKey, todayKey);
    await _sendStudyStatus();
    await _syncMonitoring();
    notifyListeners();
  }

  Future<void> resetIfNewDay() async {
    if (!isSupported) return;
    final todayKey = _todayKey();
    final shouldReset = _storedCompletionDay != null && _storedCompletionDay != todayKey;
    if (shouldReset) {
      _storedCompletionDay = null;
      if (_hasCompletedToday) {
        _hasCompletedToday = false;
        await _sendStudyStatus();
      }
      final prefs = await _ensurePrefs();
      await prefs.remove(_completionKey);
      await _syncMonitoring();
      notifyListeners();
    }
  }

  Future<void> updateStudyStatus(bool completed) async {
    if (!isSupported) return;
    if (completed) {
      await markStudyCompletedForToday();
      return;
    }
    _hasCompletedToday = false;
    _storedCompletionDay = null;
    final prefs = await _ensurePrefs();
    await prefs.remove(_completionKey);
    await _sendStudyStatus();
    await _syncMonitoring();
    notifyListeners();
  }

  Future<void> _refreshPermissions() async {
    if (!isSupported) return;
    final usage = await _invokeMethod<bool>('checkUsageAccess');
    final overlay = await _invokeMethod<bool>('checkOverlayPermission');
    _hasUsagePermission = usage ?? false;
    _hasOverlayPermission = overlay ?? false;
  }

  Future<void> _syncMonitoring() async {
    if (!isSupported || !_initialized) return;
    if (!_isEnabled || !permissionsSatisfied) {
      await _invokeMethod('stopMonitoring');
      return;
    }
    await _invokeMethod('startMonitoring', <String, dynamic>{
      'blockedApps': blockedPackages,
      'appLockEnabled': _isEnabled,
      'studyCompleted': _hasCompletedToday,
    });
  }

  Future<void> _sendStudyStatus() async {
    if (!isSupported) return;
    await _invokeMethod('updateStudyStatus', <String, dynamic>{
      'completed': _hasCompletedToday,
    });
  }

  Future<T?> _invokeMethod<T>(String method, [Object? arguments]) async {
    if (!isSupported) return null;
    try {
      final result = await _channel.invokeMethod<T>(method, arguments);
      return result;
    } on PlatformException catch (error) {
      debugPrint('AppLockProvider: $method failed: ${error.message ?? error.code}');
    } on MissingPluginException catch (error) {
      debugPrint('AppLockProvider missing plugin: $error');
    }
    return null;
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  Future<SharedPreferences> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<bool> _promptCreatePin(BuildContext context) async {
    if (!context.mounted) return false;
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? error;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Set Security PIN'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Add a 4-digit PIN to prevent others from disabling App Lock Mode.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'PIN',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Confirm PIN',
                    counterText: '',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: Colors.redAccent)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final pin = pinController.text.trim();
                  final confirm = confirmController.text.trim();
                  if (pin.length != 4 || confirm.length != 4) {
                    setState(() => error = 'PIN must be 4 digits.');
                    return;
                  }
                  if (pin != confirm) {
                    setState(() => error = 'PINs do not match.');
                    return;
                  }
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('Save PIN'),
              ),
            ],
          ),
        );
      },
    );
    String? pin;
    if (result == true) {
      pin = pinController.text.trim();
    }
    if (pin == null || pin.isEmpty) {
      return false;
    }
    _securityPin = pin;
    final prefs = await _ensurePrefs();
    await prefs.setString(_pinKey, pin);
    return true;
  }

  Future<bool> _verifyPinBeforeDisable(BuildContext context) async {
    if (_securityPin == null) {
      return true;
    }
    if (!context.mounted) return false;
    final controller = TextEditingController();
    String? error;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Enter Security PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter your 4-digit PIN to turn off App Lock Mode.'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  counterText: '',
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.redAccent)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final entered = controller.text.trim();
                if (entered != _securityPin) {
                  setState(() => error = 'Incorrect PIN.');
                  return;
                }
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Unlock'),
            ),
          ],
        ),
      ),
    );
    final entered = controller.text.trim();
    if (result == true && entered == _securityPin) {
      return true;
    }
    if (result == true) {
      // dialog closed but pin mismatch cleared it already
      return false;
    }
    return result ?? false;
  }

  Future<void> setMinimumSessionMinutes(int minutes) async {
    final normalized = minutes.clamp(5, 180);
    if (_minimumSessionMinutes == normalized) return;
    _minimumSessionMinutes = normalized;
    final prefs = await _ensurePrefs();
    await prefs.setInt(_minDurationKey, _minimumSessionMinutes);
    notifyListeners();
  }

  Future<bool> registerCompletedSession(int actualMinutes) async {
    if (!isSupported) return true;
    if (actualMinutes < _minimumSessionMinutes) {
      return false;
    }
    await markStudyCompletedForToday();
    return true;
  }
}
