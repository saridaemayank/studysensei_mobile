import 'package:shared_preferences/shared_preferences.dart';

class OnboardingStorage {
  static const completedKey = 'study_sensei_onboarding_completed';

  const OnboardingStorage();

  static Future<bool> isCompleted() {
    return const OnboardingStorage().getOnboardingCompleted();
  }

  static Future<void> setCompleted() {
    return const OnboardingStorage().setOnboardingCompleted(true);
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(completedKey);
  }

  Future<bool> getOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(completedKey) ?? false;
  }

  Future<void> setOnboardingCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(completedKey, value);
  }
}
