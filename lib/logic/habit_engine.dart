import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 🗄️ Local Storage Service (100% stable, HabitEngine-compatible)
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

  // ===================== STATIC HELPERS =====================

  static Future<void> saveHabits(List<Map<String, dynamic>> habits) async {
    final s = LocalStorage();
    await s.saveAllHabits(habits);
  }

  static Future<List<Map<String, dynamic>>> loadHabits() async {
    final s = LocalStorage();
    return await s.getAllHabits();
  }

  // ===================== HABITS =====================

  Future<List<Map<String, dynamic>>> getAllHabits() async {
    await init();
    final data = _prefs.getString('habits') ?? '[]';
    final List decoded = jsonDecode(data);
    return decoded.map((h) => Map<String, dynamic>.from(h)).toList();
  }

  Future<void> saveAllHabits(List<Map<String, dynamic>> habits) async {
    await init();
    await _prefs.setString('habits', jsonEncode(habits));
  }

  Future<void> saveHabit(Map<String, dynamic> habit) async {
    final all = await getAllHabits();
    final idx = all.indexWhere((h) => h['id'] == habit['id']);
    if (idx >= 0) {
      all[idx] = habit;
    } else {
      all.add(habit);
    }
    await saveAllHabits(all);
  }

  Future<void> deleteHabit(String id) async {
    final all = await getAllHabits();
    all.removeWhere((h) => h['id'] == id);
    await saveAllHabits(all);
  }

  // ===================== COMPLETION =====================

  Future<void> markCompleted(String id, DateTime date) async {
    await init();
    final key = 'done:$id:${_ymd(date)}';
    await _prefs.setBool(key, true);
  }

  Future<bool> isCompletedOn(String id, DateTime date) async {
    await init();
    final key = 'done:$id:${_ymd(date)}';
    return _prefs.getBool(key) ?? false;
  }

  // ===================== STREAKS =====================

  Future<int> getStreak(String id) async {
    await init();
    return _prefs.getInt('streak:$id') ?? 0;
  }

  Future<void> setStreak(String id, int val) async {
    await init();
    await _prefs.setInt('streak:$id', val);
  }

  Future<DateTime?> getLastCompletionDate(String id) async {
    await init();
    final s = _prefs.getString('lastComplete:$id');
    if (s == null) return null;
    return DateTime.tryParse(s);
  }

  Future<void> setLastCompletionDate(String id, DateTime date) async {
    await init();
    await _prefs.setString('lastComplete:$id', date.toIso8601String());
  }

  // ===================== XP =====================

  Future<int> getTotalXP() async {
    await init();
    return _prefs.getInt('xp:total') ?? 0;
  }

  Future<int> addXP(int amount) async {
    await init();
    final c = await getTotalXP();
    final newVal = c + amount;
    await _prefs.setInt('xp:total', newVal);
    return newVal;
  }

  Future<int> getHabitXP(String id) async {
    await init();
    return _prefs.getInt('xp:$id') ?? 0;
  }

  Future<void> addHabitXP(String id, int amount) async {
    await init();
    final c = await getHabitXP(id);
    await _prefs.setInt('xp:$id', c + amount);
  }

  // ===================== HELPERS =====================

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Global singleton instance
final localStorage = LocalStorage();
