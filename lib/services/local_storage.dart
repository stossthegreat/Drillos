import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 🗄️ Local Storage Service - All habit data lives here
class LocalStorage {
  static final LocalStorage _instance = LocalStorage._internal();
  factory LocalStorage() => _instance;
  LocalStorage._internal();

  late SharedPreferences _prefs;
  bool _initialized = false;

  Future<void> init() async {
    if (!_initialized) {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
    }
  }

  // ========== HABITS ==========

  static Future<void> saveHabits(List<Map<String, dynamic>> habits) async {
    final storage = LocalStorage();
    await storage.saveAllHabits(habits);
  }

  static Future<List<Map<String, dynamic>>> loadHabits() async {
    final storage = LocalStorage();
    return await storage.getAllHabits();
  }

  Future<List<Map<String, dynamic>>> getAllHabits() async {
    await init();
    final habitsJson = _prefs.getString('habits') ?? '[]';
    final List<dynamic> decoded = jsonDecode(habitsJson);
    return decoded.map((h) => Map<String, dynamic>.from(h)).toList();
  }

  Future<void> saveAllHabits(List<Map<String, dynamic>> habits) async {
    await init();
    await _prefs.setString('habits', jsonEncode(habits));
  }

  Future<void> saveHabit(Map<String, dynamic> habit) async {
    final habits = await getAllHabits();
    final index = habits.indexWhere((h) => h['id'] == habit['id']);
    if (index >= 0) {
      habits[index] = habit;
    } else {
      habits.add(habit);
    }
    await saveAllHabits(habits);
  }

  Future<void> deleteHabit(String habitId) async {
    final habits = await getAllHabits();
    habits.removeWhere((h) => h['id'] == habitId);
    await saveAllHabits(habits);
  }

  // ========== COMPLETION TRACKING ==========

  Future<void> markCompleted(String habitId, DateTime date) async {
    await init();
    final key = 'done:$habitId:${_ymd(date)}';
    await _prefs.setBool(key, true);
  }

  Future<bool> isCompletedOn(String habitId, DateTime date) async {
    await init();
    final key = 'done:$habitId:${_ymd(date)}';
    return _prefs.getBool(key) ?? false;
  }

  // ========== STREAKS ==========

  Future<int> getStreak(String habitId) async {
    await init();
    return _prefs.getInt('streak:$habitId') ?? 0;
  }

  Future<void> setStreak(String habitId, int streak) async {
    await init();
    await _prefs.setInt('streak:$habitId', streak);
  }

  Future<DateTime?> getLastCompletionDate(String habitId) async {
    await init();
    final dateStr = _prefs.getString('lastComplete:$habitId');
    if (dateStr == null) return null;
    return DateTime.tryParse(dateStr);
  }

  Future<void> setLastCompletionDate(String habitId, DateTime date) async {
    await init();
    await _prefs.setString('lastComplete:$habitId', date.toIso8601String());
  }

  // ========== XP ==========

  Future<int> getTotalXP() async {
    await init();
    return _prefs.getInt('xp:total') ?? 0;
  }

  Future<int> addXP(int amount) async {
    await init();
    final current = await getTotalXP();
    final newTotal = current + amount;
    await _prefs.setInt('xp:total', newTotal);
    return newTotal;
  }

  Future<int> getHabitXP(String habitId) async {
    await init();
    return _prefs.getInt('xp:$habitId') ?? 0;
  }

  Future<void> addHabitXP(String habitId, int amount) async {
    await init();
    final current = await getHabitXP(habitId);
    await _prefs.setInt('xp:$habitId', current + amount);
  }

  // ========== OVERALL STATS ==========

  Future<int> getOverallStreak() async {
    final habits = await getAllHabits();
    int maxStreak = 0;
    for (final habit in habits) {
      final streak = await getStreak(habit['id']);
      if (streak > maxStreak) maxStreak = streak;
    }
    return maxStreak;
  }

  // ========== ALARMS ==========

  Future<String?> getAlarmTime(String habitId) async {
    await init();
    return _prefs.getString('alarm:$habitId');
  }

  Future<void> setAlarmTime(String habitId, String time) async {
    await init();
    await _prefs.setString('alarm:$habitId', time);
  }

  Future<void> removeAlarm(String habitId) async {
    await init();
    await _prefs.remove('alarm:$habitId');
  }

  // ========== SYNC ==========

  Future<DateTime?> getLastSyncTime() async {
    await init();
    final timestamp = _prefs.getInt('lastSync');
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  Future<void> setLastSyncTime(DateTime time) async {
    await init();
    await _prefs.setInt('lastSync', time.millisecondsSinceEpoch);
  }

  // ========== HELPERS ==========

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> clearAll() async {
    await init();
    await _prefs.clear();
  }

  // ========== CLEANUP FIX ==========

  /// 🧹 Remove broken or old ghost habits with no valid ID or type
  Future<void> cleanupInvalidHabits() async {
    await init();
    final all = await getAllHabits();
    final cleaned = all.where((h) {
      final id = h['id'];
      final type = h['type'];
      return id != null &&
          id.toString().trim().isNotEmpty &&
          (type == 'habit' || type == 'task' || type == 'bad');
    }).toList();

    if (cleaned.length != all.length) {
      await saveAllHabits(cleaned);
      print('🧹 Cleaned ${all.length - cleaned.length} invalid habits/tasks');
    }
  }
}

final localStorage = LocalStorage();
