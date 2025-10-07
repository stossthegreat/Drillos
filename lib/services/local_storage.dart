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

  // Simple static helpers (requested interface)
  static Future<void> saveHabits(List<Map<String, dynamic>> habits) async {
    final storage = LocalStorage();
    await storage.saveAllHabits(habits);
  }

  static Future<List<Map<String, dynamic>>> loadHabits() async {
    final storage = LocalStorage();
    return await storage.getAllHabits();
  }

  /// Get all habits from local storage
  Future<List<Map<String, dynamic>>> getAllHabits() async {
    await init();
    final habitsJson = _prefs.getString('habits') ?? '[]';
    final List<dynamic> decoded = jsonDecode(habitsJson);
    return decoded.map((h) => Map<String, dynamic>.from(h)).toList();
  }

  /// Save all habits to local storage
  Future<void> saveAllHabits(List<Map<String, dynamic>> habits) async {
    await init();
    await _prefs.setString('habits', jsonEncode(habits));
  }

  /// Add or update a single habit
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

  /// Delete a habit
  Future<void> deleteHabit(String habitId) async {
    final habits = await getAllHabits();
    habits.removeWhere((h) => h['id'] == habitId);
    await saveAllHabits(habits);
  }

  // ========== COMPLETION TRACKING ==========

  /// Mark habit as completed for a specific date
  Future<void> markCompleted(String habitId, DateTime date) async {
    await init();
    final key = 'done:$habitId:${_ymd(date)}';
    await _prefs.setBool(key, true);
  }

  /// Check if habit was completed on a specific date
  Future<bool> isCompletedOn(String habitId, DateTime date) async {
    await init();
    final key = 'done:$habitId:${_ymd(date)}';
    return _prefs.getBool(key) ?? false;
  }

  // ========== STREAKS ==========

  /// Get current streak for a habit
  Future<int> getStreak(String habitId) async {
    await init();
    return _prefs.getInt('streak:$habitId') ?? 0;
  }

  /// Set streak for a habit
  Future<void> setStreak(String habitId, int streak) async {
    await init();
    await _prefs.setInt('streak:$habitId', streak);
  }

  /// Get last completion date for a habit
  Future<DateTime?> getLastCompletionDate(String habitId) async {
    await init();
    final dateStr = _prefs.getString('lastComplete:$habitId');
    if (dateStr == null) return null;
    return DateTime.tryParse(dateStr);
  }

  /// Set last completion date for a habit
  Future<void> setLastCompletionDate(String habitId, DateTime date) async {
    await init();
    await _prefs.setString('lastComplete:$habitId', date.toIso8601String());
  }

  // ========== XP ==========

  /// Get total XP
  Future<int> getTotalXP() async {
    await init();
    return _prefs.getInt('xp:total') ?? 0;
  }

  /// Add XP
  Future<int> addXP(int amount) async {
    await init();
    final current = await getTotalXP();
    final newTotal = current + amount;
    await _prefs.setInt('xp:total', newTotal);
    return newTotal;
  }

  /// Get XP for a specific habit
  Future<int> getHabitXP(String habitId) async {
    await init();
    return _prefs.getInt('xp:$habitId') ?? 0;
  }

  /// Add XP to a specific habit
  Future<void> addHabitXP(String habitId, int amount) async {
    await init();
    final current = await getHabitXP(habitId);
    await _prefs.setInt('xp:$habitId', current + amount);
  }

  // ========== OVERALL STATS ==========

  /// Get overall streak (longest current streak across all habits)
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

  /// Get alarm time for a habit
  Future<String?> getAlarmTime(String habitId) async {
    await init();
    return _prefs.getString('alarm:$habitId');
  }

  /// Set alarm time for a habit
  Future<void> setAlarmTime(String habitId, String time) async {
    await init();
    await _prefs.setString('alarm:$habitId', time);
  }

  /// Remove alarm for a habit
  Future<void> removeAlarm(String habitId) async {
    await init();
    await _prefs.remove('alarm:$habitId');
  }

  // ========== SYNC ==========

  /// Get last sync timestamp
  Future<DateTime?> getLastSyncTime() async {
    await init();
    final timestamp = _prefs.getInt('lastSync');
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// Set last sync timestamp
  Future<void> setLastSyncTime(DateTime time) async {
    await init();
    await _prefs.setInt('lastSync', time.millisecondsSinceEpoch);
  }

  // ========== HELPERS ==========

  String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Clear all data (for testing/reset)
  Future<void> clearAll() async {
    await init();
    await _prefs.clear();
  }
}

final localStorage = LocalStorage();

