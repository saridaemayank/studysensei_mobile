import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class FocusSessionStorage {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> state);
}

class PreferencesFocusSessionStorage implements FocusSessionStorage {
  static const key = 'focus.session.v1';
  @override
  Future<Map<String, dynamic>?> read() async {
    final value = (await SharedPreferences.getInstance()).getString(key);
    return value == null ? null : jsonDecode(value) as Map<String, dynamic>;
  }

  @override
  Future<void> write(Map<String, dynamic> state) async {
    final saved = await (await SharedPreferences.getInstance())
        .setString(key, jsonEncode(state));
    if (!saved) throw StateError('Focus persistence unavailable');
  }
}
