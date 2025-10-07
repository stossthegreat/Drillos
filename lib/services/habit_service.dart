import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'local_storage.dart';
import 'api_client.dart';
import 'alarm_service.dart';

/// 🎯 Habit Service - Complete offline-first habit management
/// - All CRUD is local-first for instant UI
/// - Scheduling logic lives here (start/end/daysOfWeek/everyN)
/// - Streak/XP & per-day completion stored in SharedPreferences via LocalStorage
class HabitService {
  static final HabitService _instance = HabitService._internal();
  factory HabitService() => _instance;
  HabitService._internal();

  final _storage = localStorage;
  final _api = ApiClient();
  final _alarms = alarmService;
  final _uuid = const Uuid();

  /// ✅ Create a new habit (OFFLINE-FIRST)
  Future<Map<String, dynamic>> createHabit(Map<String, dynamic> data) async {
    final habitId = _uuid.v4();
    final now = DateTime.now();

    final habit = {
      'id': habitId,
      'title': data['name'] ?? data['title'] ?? 'New Habit',
      'name': data['name'] ?? data['title'] ?? 'New Habit',
      'color': data['color'] ?? 'emerald',
      'streak': 0,
      'xp': 0,
      'completed': false,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'type': 'habit',
      'schedule': _buildSchedule(data),
      'reminderEnabled': data['reminderOn'] ?? false,
      'reminderTime': data['reminderTime'],
      'intensity': data['intensity'] ?? 2,
    };

    await _storage.saveHabit(habit);

    if (habit['reminderEnabled'] == true && habit['reminderTime'] != null) {
      await _createHabitAlarm(habit);
    }

    _syncHabitToBackend(habit); // fire-and-forget
    return habit;
  }

  /// ✅ Create a new task (OFFLINE-FIRST)
  Future<Map<String, dynamic>> createTask(Map<String, dynamic> data) async {
    final taskId = _uuid.v4();
    final now = DateTime.now();

    final task = {
      'id': taskId,
      'title': data['name'] ?? data['title'] ?? 'New Task',
      'name': data['name'] ?? data['title'] ?? 'New Task',
      'color': data['color'] ?? 'blue',
      'completed': false,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'type': 'task',
      'dueDate': data['endDate'] ?? now.add(const Duration(days: 1)).toIso8601String(),
      'schedule': _buildSchedule(data),
      'reminderEnabled': data['reminderOn'] ?? false,
      'reminderTime': data['reminderTime'],
      'priority': data['intensity'] ?? 2,
    };

    await _storage.saveHabit(task);

    if (task['reminderEnabled'] == true && task['reminderTime'] != null) {
      await _createTaskAlarm(task);
    }

    _syncTaskToBackend(task); // fire-and-forget
    return task;
  }

  /// ✅ Update a habit/task
  Future<Map<String, dynamic>> updateHabit(String id, Map<String, dynamic> data) async {
    final habits = await _storage.getAllHabits();
    final existing = habits.firstWhere((h) => h['id'] == id, orElse: () => <String, dynamic>{});
    if (existing.isEmpty) throw Exception('Habit not found: $id');

    final updated = {
      ...existing,
      ...data,
      'id': id,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    if (data.containsKey('name') || data.containsKey('schedule') || data.containsKey('frequency')) {
      updated['schedule'] = _buildSchedule({...existing, ...data});
    }

    await _storage.saveHabit(updated);

    if (data.containsKey('reminderOn') || data.containsKey('reminderTime')) {
      if (updated['reminderEnabled'] == true && updated['reminderTime'] != null) {
        await _createHabitAlarm(updated);
      } else {
        await _alarms.cancelAlarm(id);
      }
    }

    _syncHabitToBackend(updated); // fire-and-forget
    return updated;
  }

  /// ✅ Delete a habit/task
  Future<void> deleteHabit(String id) async {
    await _storage.deleteHabit(id);
    try {
      await _alarms.cancelAlarm(id);
    } catch (_) {}
    try {
      await _api.deleteHabit(id);
    } catch (_) {}
  }

  /// ✅ Get all (raw)
  Future<List<Map<String, dynamic>>> getAllHabits() => _storage.getAllHabits();

  /// ✅ Get habits filtered for *today* (legacy keep)
  Future<List<Map<String, dynamic>>> getTodayHabits() => getHabitsForDate(DateTime.now());

  /// ✅ Get habits filtered for ANY date (Home calendar uses this)
  Future<List<Map<String, dynamic>>> getHabitsForDate(DateTime date) async {
    final allHabits = await _storage.getAllHabits();
    final result = <Map<String, dynamic>>[];

    for (final habit in allHabits) {
      final schedule = habit['schedule'] as Map<String, dynamic>?;

      final isActive = schedule == null ? true : _isActiveOn(schedule, date);
      if (!isActive) continue;

      final completed = await _storage.isCompletedOn(habit['id'], date);

      if (habit['type'] == 'task') {
        result.add({
          ...Map<String, dynamic>.from(habit),
          'completed': completed,
        });
      } else {
        final streak = await _storage.getStreak(habit['id']);
        result.add({
          ...Map<String, dynamic>.from(habit),
          'completed': completed,
          'streak': streak,
        });
      }
    }

    return result;
  }

  // ========== PRIVATE HELPERS ==========

  Map<String, dynamic> _buildSchedule(Map<String, dynamic> data) {
    final frequency = data['frequency'] ?? 'daily';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    Map<String, dynamic> schedule;

    if (frequency == 'daily') {
      schedule = {
        'startDate': data['startDate'] ?? today.toIso8601String(),
        'endDate': data['endDate'],
        'daysOfWeek': [1, 2, 3, 4, 5, 6, 7],
      };
    } else if (frequency == 'weekdays') {
      schedule = {
        'startDate': data['startDate'] ?? today.toIso8601String(),
        'endDate': data['endDate'],
        'daysOfWeek': [1, 2, 3, 4, 5],
      };
    } else if (frequency == 'weekends') {
      schedule = {
        'startDate': data['startDate'] ?? today.toIso8601String(),
        'endDate': data['endDate'],
        'daysOfWeek': [6, 7],
      };
    } else if (frequency == 'everyN') {
      final everyN = data['everyN'] ?? 2;
      schedule = {
        'startDate': data['startDate'] ?? today.toIso8601String(),
        'endDate': data['endDate'],
        'daysOfWeek': [1, 2, 3, 4, 5, 6, 7], // use everyN filter below
        'everyN': everyN,
        'lastCompleted': null,
      };
    } else if (frequency == 'custom' && data['daysOfWeek'] != null) {
      schedule = {
        'startDate': data['startDate'] ?? today.toIso8601String(),
        'endDate': data['endDate'],
        'daysOfWeek': data['daysOfWeek'],
      };
    } else {
      schedule = {
        'startDate': data['startDate'] ?? today.toIso8601String(),
        'endDate': data['endDate'],
        'daysOfWeek': [1, 2, 3, 4, 5, 6, 7],
      };
    }

    return schedule;
  }

  bool _isActiveOn(Map<String, dynamic> schedule, DateTime date) {
    final d = DateTime(date.year, date.month, date.day);

    final startDateStr = schedule['startDate'] as String?;
    if (startDateStr != null) {
      final startDate = DateTime.parse(startDateStr);
      final s = DateTime(startDate.year, startDate.month, startDate.day);
      if (d.isBefore(s)) return false;
    }

    final endDateStr = schedule['endDate'] as String?;
    if (endDateStr != null && endDateStr.isNotEmpty) {
      final endDate = DateTime.parse(endDateStr);
      final e = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      if (d.isAfter(e)) return false;
    }

    if (schedule['everyN'] != null) {
      final everyN = schedule['everyN'] as int? ?? 2;
      final start = DateTime.parse(startDateStr ?? DateTime.now().toIso8601String());
      final daysSinceStart =
          d.difference(DateTime(start.year, start.month, start.day)).inDays;
      return daysSinceStart % everyN == 0;
    }

    final rawDays = schedule['daysOfWeek'];
    final daysOfWeek = <int>[];
    if (rawDays is List) {
      for (final day in rawDays) {
        if (day is int && day >= 1 && day <= 7) {
          daysOfWeek.add(day);
        } else if (day is String) {
          final parsed = int.tryParse(day);
          if (parsed != null && parsed >= 1 && parsed <= 7) daysOfWeek.add(parsed);
        } else if (day is num) {
          final intDay = day.toInt();
          if (intDay >= 1 && intDay <= 7) daysOfWeek.add(intDay);
        }
      }
    }
    if (daysOfWeek.isEmpty) daysOfWeek.addAll([1, 2, 3, 4, 5, 6, 7]);

    return daysOfWeek.contains(d.weekday);
  }

  Future<void> _createHabitAlarm(Map<String, dynamic> habit) async {
    try {
      final schedule = habit['schedule'] as Map<String, dynamic>?;
      final daysOfWeek = (schedule?['daysOfWeek'] as List?)?.cast<int>() ??
          [1, 2, 3, 4, 5, 6, 7];

      await _alarms.scheduleAlarm(
        habitId: habit['id'],
        habitName: habit['title'] ?? habit['name'],
        time: habit['reminderTime'],
        daysOfWeek: daysOfWeek,
        mentorMessage: '⚡ Time to complete: ${habit['title'] ?? habit['name']}',
      );
    } catch (_) {}
  }

  Future<void> _createTaskAlarm(Map<String, dynamic> task) async {
    try {
      final schedule = task['schedule'] as Map<String, dynamic>?;
      List<int> daysOfWeek = [1, 2, 3, 4, 5, 6, 7];
      final rawDays = schedule?['daysOfWeek'];
      if (rawDays is List) {
        final parsed = <int>[];
        for (final day in rawDays) {
          if (day is int && day >= 1 && day <= 7) parsed.add(day);
          else if (day is String) {
            final d = int.tryParse(day);
            if (d != null && d >= 1 && d <= 7) parsed.add(d);
          } else if (day is num) {
            final d = day.toInt();
            if (d >= 1 && d <= 7) parsed.add(d);
          }
        }
        if (parsed.isNotEmpty) daysOfWeek = parsed;
      }

      await _alarms.scheduleAlarm(
        habitId: task['id'],
        habitName: task['title'] ?? task['name'],
        time: task['reminderTime'],
        daysOfWeek: daysOfWeek,
        mentorMessage: '📋 Task reminder: ${task['title'] ?? task['name']}',
      );
    } catch (_) {}
  }

  /// ✅ Mark a task as completed locally for a date
  Future<void> completeTaskLocal(String taskId, {DateTime? when}) async {
    final date = when ?? DateTime.now();
    await _storage.markCompleted(taskId, date);

    final items = await _storage.getAllHabits();
    final index = items.indexWhere((i) => i['id'] == taskId);
    if (index >= 0) {
      items[index] = {
        ...items[index],
        'completed': true,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await _storage.saveAllHabits(items);
    }
  }

  // ---- Backend sync (fire-and-forget) ----
  void _syncHabitToBackend(Map<String, dynamic> habit) {
    _api.createHabit({
      'title': habit['title'] ?? habit['name'],
      'schedule': habit['schedule'],
      'color': habit['color'],
      'reminderEnabled': habit['reminderEnabled'],
      'reminderTime': habit['reminderTime'],
    }).catchError((_) {});
  }

  void _syncTaskToBackend(Map<String, dynamic> task) {
    _api.createTask({
      'title': task['title'] ?? task['name'],
      'dueDate': task['dueDate'],
      'description': task['description'] ?? '',
      'priority': task['priority'],
      'color': task['color'],
    }).catchError((_) {});
  }
}

final habitService = HabitService();
