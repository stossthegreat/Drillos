import 'package:shared_preferences/shared_preferences.dart';

class HabitEngine {
  static String _ymd(DateTime d) => '${d.year}-${d.month}-${d.day}';

  static Future<void> applyLocalTick({
    required String habitId,
    required void Function(int newStreak, int newXp) onApplied,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = 'done:$habitId:${_ymd(DateTime.now())}';
    final streakKey = 'streak:$habitId';
    final xpKey = 'xp:total';

    final already = prefs.getBool(todayKey) ?? false;
    if (already) {
      onApplied(prefs.getInt(streakKey) ?? 0, prefs.getInt(xpKey) ?? 0);
      return;
    }

    final currentStreak = prefs.getInt(streakKey) ?? 0;
    final newStreak = currentStreak + 1;
    final currentXp = prefs.getInt(xpKey) ?? 0;
    // Award 15 XP per completed day (example)
    final newXp = currentXp + 15;

    await prefs.setBool(todayKey, true);
    await prefs.setInt(streakKey, newStreak);
    await prefs.setInt(xpKey, newXp);

    onApplied(newStreak, newXp);
  }
}

