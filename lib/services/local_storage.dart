import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 🗄️ Local Storage Service - handles all habits, streaks, and local data.
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

  // 🧹 Clean invalid / ghost habits left from older builds
  Future<void> cleanupInvalidHabits() async {
    await init();
    final habitsJson = _prefs.getString('habits');
    if (habitsJson == null) return;

    try {
      final List<dynamic> decoded = jsonDecode(habitsJson);
      final valid = decoded
          .whereType<Map>()
          .where((h) => (h['id'] != null && h['name'] != null))
          .toList();

      if (valid.length != decoded.length) {
        await _prefs.setString('habits', jsonEncode(valid));
        print('🧹 Cleaned up ${decoded.length - valid.length} invalid habits');
      }
    } catch (e) {
      print('⚠️ Habit cleanup failed: $e — resetting store');
      await _prefs.remove('habits');
    }
  }

  // ========== HABITS ==========

  Future<List<Map<String, dynamic>>> getAllHabits() async {
    await init();
    final habitsJson = _prefs.getString('habits') ?? '[]';
    final List decoded = jsonDecode(habitsJson);
    return decoded.map((h) => Map<String, dynamic>.from(h)).toList();
  }

  Future<void> saveAllHabits(List<Map<String, dynamic>> habits) async {
    await init();
    await _prefs.setString('habits', jsonEncode(habits));
  }

  Future<void> saveHabit(Map<String, dynamic> habit) async {
    final habits = await getAllHabits();
    final idx = habits.indexWhere((h) => h['id'] == habit['id']);
    if (idx >= 0) {
      habits[idx] = habit;
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

  // ========== COMPLETION ==========

  Future<void> markCompleted(String id, DateTime date) async {
    await init();
    await _prefs.setBool('done:$id:${_ymd(date)}', true);
  }

  Future<bool> isCompletedOn(String id, DateTime date) async {
    await init();
    return _prefs.getBool('done:$id:${_ymd(date)}') ?? false;
  }

  // ========== STREAKS ==========

  Future<int> getStreak(String id) async {
    await init();
    return _prefs.getInt('streak:$id') ?? 0;
  }

  Future<void> setStreak(String id, int streak) async {
    await init();
    await _prefs.setInt('streak:$id', streak);
  }

  // ========== XP / STATS ==========

  Future<int> getTotalXP() async {
    await init();
    return _prefs.getInt('xp:total') ?? 0;
  }

  Future<int> addXP(int amount) async {
    await init();
    final total = await getTotalXP() + amount;
    await _prefs.setInt('xp:total', total);
    return total;
  }

  // ========== ALARMS ==========

  Future<String?> getAlarmTime(String id) async {
    await init();
    return _prefs.getString('alarm:$id');
  }

  Future<void> setAlarmTime(String id, String time) async {
    await init();
    await _prefs.setString('alarm:$id', time);
  }

  Future<void> removeAlarm(String id) async {
    await init();
    await _prefs.remove('alarm:$id');
  }

  // ========== HELPERS ==========

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> clearAll() async {
    await init();
    await _prefs.clear();
  }
}

final localStorage = LocalStorage();
